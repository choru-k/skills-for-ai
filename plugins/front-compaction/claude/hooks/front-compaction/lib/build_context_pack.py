#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import pathlib
import sys
from dataclasses import dataclass


class UnsupportedError(Exception):
    pass


@dataclass
class Turn:
    user: str
    assistant: str


def _normalize_text(value: str) -> str:
    lines = [line.rstrip() for line in value.splitlines()]
    return "\n".join(lines).strip()


def _first_line(value: str, max_len: int = 180) -> str:
    for line in value.splitlines():
        line = line.strip()
        if line:
            return line[:max_len]
    return ""


def _extract_user_text(entry: dict) -> str | None:
    if entry.get("type") != "user":
        return None
    message = entry.get("message") or {}
    if message.get("role") != "user":
        return None

    content = message.get("content")
    if isinstance(content, str):
        text = _normalize_text(content)
        return text or None

    if isinstance(content, list):
        if entry.get("toolUseResult") is not None:
            return None
        parts: list[str] = []
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "text":
                text = _normalize_text(str(item.get("text", "")))
                if text:
                    parts.append(text)
        text = "\n\n".join(parts).strip()
        return text or None

    return None


def _extract_assistant_text(entry: dict) -> str | None:
    if entry.get("type") != "assistant":
        return None

    message = entry.get("message") or {}
    if message.get("role") != "assistant":
        return None

    content = message.get("content")
    if not isinstance(content, list):
        return None

    parts: list[str] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get("type") == "text":
            text = _normalize_text(str(item.get("text", "")))
            if text:
                parts.append(text)

    if not parts:
        return None

    return "\n\n".join(parts).strip()


def _load_turns(transcript_path: pathlib.Path) -> list[Turn]:
    turns: list[Turn] = []

    current_user: str | None = None
    assistant_parts: list[str] = []

    with transcript_path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue

            user_text = _extract_user_text(entry)
            if user_text:
                if current_user and assistant_parts:
                    turns.append(Turn(user=current_user, assistant="\n\n".join(assistant_parts).strip()))
                current_user = user_text
                assistant_parts = []
                continue

            assistant_text = _extract_assistant_text(entry)
            if assistant_text and current_user:
                assistant_parts.append(assistant_text)

    if current_user and assistant_parts:
        turns.append(Turn(user=current_user, assistant="\n\n".join(assistant_parts).strip()))

    return turns


def _render_head_summary(head_turns: list[Turn], percent: int, total_turns: int, compacted_turns: int, focus: str, max_chars: int) -> str:
    lines: list[str] = [
        f"Front compaction summary ({percent}%): compacted {compacted_turns}/{total_turns} turns.",
    ]
    if focus:
        lines.append(f"Focus: {focus}")
    lines.append("Compacted head highlights:")

    for idx, turn in enumerate(head_turns, start=1):
        user_line = _first_line(turn.user)
        assistant_line = _first_line(turn.assistant)
        lines.append(f"- Turn {idx} user: {user_line}")
        lines.append(f"  Turn {idx} assistant: {assistant_line}")

    summary = "\n".join(lines).strip()
    if len(summary) <= max_chars:
        return summary

    suffix = "\n_summary truncated to fit maxHeadChars_"
    allowed = max(0, max_chars - len(suffix))
    return summary[:allowed].rstrip() + suffix


def _render_turn_block(turn: Turn, turn_number: int) -> str:
    return (
        f"### Turn {turn_number}\n"
        f"User:\n{turn.user}\n\n"
        f"Assistant:\n{turn.assistant}\n"
    )


def _build_tail_content(tail_turns: list[Turn], compacted_turns: int, max_tail_chars: int) -> tuple[str, int, bool]:
    blocks = [_render_turn_block(turn, compacted_turns + idx + 1) for idx, turn in enumerate(tail_turns)]
    truncated = False

    while blocks and len("\n".join(blocks)) > max_tail_chars:
        blocks.pop(0)
        truncated = True

    if not blocks:
        raise UnsupportedError("tail replay became empty after applying maxTailChars limit")

    content = "\n".join(blocks).strip()
    return content, len(blocks), truncated


def _build_replay(summary: str, tail_raw: str) -> str:
    return (
        "## Front Compaction Replay (hard mode)\n\n"
        "### Head Summary\n"
        f"{summary}\n\n"
        "### Raw Tail Replay\n"
        f"{tail_raw}"
    )


def _truncate_replay_to_cap(
    tail_turns: list[Turn],
    compacted_turns: int,
    summary: str,
    max_tail_chars: int,
    max_replay_chars: int,
) -> tuple[str, str, int, bool]:
    tail_content, tail_count, truncated = _build_tail_content(tail_turns, compacted_turns, max_tail_chars)
    replay = _build_replay(summary, tail_content)

    if len(replay) <= max_replay_chars:
        return replay, tail_content, tail_count, truncated

    blocks = [_render_turn_block(turn, compacted_turns + idx + 1) for idx, turn in enumerate(tail_turns)]
    dropped = False

    while blocks and len(_build_replay(summary, "\n".join(blocks).strip())) > max_replay_chars:
        blocks.pop(0)
        dropped = True

    if not blocks:
        raise UnsupportedError("replay payload exceeds maxReplayChars with no tail turns left")

    tail_content = "\n".join(blocks).strip()
    replay = _build_replay(summary, tail_content)

    if len(replay) > max_replay_chars:
        marker = "\n_tail replay truncated to fit maxReplayChars_"
        allowed = max(0, max_replay_chars - len(marker))
        replay = replay[:allowed].rstrip() + marker
        tail_content = tail_content[: max(0, max_tail_chars - len(marker))].rstrip() + marker
        dropped = True

    return replay, tail_content, len(blocks), (truncated or dropped)


def build_context_pack(args: argparse.Namespace) -> dict:
    transcript_path = pathlib.Path(args.transcript_path)
    if not transcript_path.is_file():
        raise UnsupportedError(f"transcript file not found: {transcript_path}")

    turns = _load_turns(transcript_path)
    total_turns = len(turns)

    if total_turns < 4:
        raise UnsupportedError(
            f"front compaction at {args.percent}% requires at least 4 complete user+assistant turns"
        )

    compacted_turns = math.floor((total_turns * args.percent) / 100)
    kept_turns = total_turns - compacted_turns

    if compacted_turns < 1 or kept_turns < 1:
        raise UnsupportedError(
            f"front compaction at {args.percent}% could not compute a safe head/tail boundary"
        )

    head_turns = turns[:compacted_turns]
    tail_turns = turns[compacted_turns:]

    summary = _render_head_summary(
        head_turns=head_turns,
        percent=args.percent,
        total_turns=total_turns,
        compacted_turns=compacted_turns,
        focus=args.focus,
        max_chars=args.max_head_chars,
    )

    replay, tail_raw_content, tail_count, tail_truncated = _truncate_replay_to_cap(
        tail_turns=tail_turns,
        compacted_turns=compacted_turns,
        summary=summary,
        max_tail_chars=args.max_tail_chars,
        max_replay_chars=args.max_replay_chars,
    )

    digest = hashlib.sha256(replay.encode("utf-8")).hexdigest()

    created_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    pack = {
        "schemaVersion": "1",
        "mode": "hard",
        "percent": args.percent,
        "focus": args.focus,
        "createdAt": created_at,
        "session": {
            "sessionId": args.session_id,
            "transcriptPath": str(transcript_path),
            "totalTurns": total_turns,
            "compactedTurns": compacted_turns,
            "keptTurns": kept_turns,
        },
        "headSummary": {
            "format": "markdown",
            "content": summary,
            "charCount": len(summary),
        },
        "tailRaw": {
            "format": "markdown",
            "turnCount": tail_count,
            "content": tail_raw_content,
            "charCount": len(tail_raw_content),
            "truncated": tail_truncated,
        },
        "replay": {
            "format": "markdown",
            "content": replay,
            "charCount": len(replay),
        },
        "limits": {
            "maxHeadChars": args.max_head_chars,
            "maxTailChars": args.max_tail_chars,
            "maxReplayChars": args.max_replay_chars,
        },
        "integrity": {
            "sha256": digest,
            "valid": True,
        },
    }

    return pack


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build front-compaction context pack")
    parser.add_argument("--transcript-path", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--percent", required=True, type=int)
    parser.add_argument("--focus", default="")
    parser.add_argument("--max-head-chars", type=int, default=4000)
    parser.add_argument("--max-tail-chars", type=int, default=16000)
    parser.add_argument("--max-replay-chars", type=int, default=19000)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        pack = build_context_pack(args)
    except UnsupportedError as exc:
        print(f"Unsupported: {exc}", file=sys.stderr)
        return 2

    json.dump(pack, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
