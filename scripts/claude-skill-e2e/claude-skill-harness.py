#!/usr/bin/env python3
"""Claude skill testing harness.

This script provides a machine-friendly wrapper around `claude --print`
for repeatable skill/extension testing from Pi.

Modes:
- run: execute one prompt and persist artifacts
- case: execute one JSON test case and evaluate assertions
  - supports single-turn and multi-turn (`turns`) cases
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S-%f")


def sanitize_name(value: str) -> str:
    sanitized = "".join(ch if ch.isalnum() or ch in ("-", "_") else "-" for ch in value.strip().lower())
    sanitized = "-".join(part for part in sanitized.split("-") if part)
    return sanitized[:80] if sanitized else "run"


def load_prompt(prompt: str | None, prompt_file: str | None) -> str:
    if bool(prompt) == bool(prompt_file):
        raise ValueError("Specify exactly one of prompt or prompt_file")

    if prompt is not None:
        return prompt

    assert prompt_file is not None
    file_path = Path(prompt_file).expanduser()
    if not file_path.is_file():
        raise ValueError(f"Prompt file not found: {file_path}")

    return file_path.read_text(encoding="utf-8")


def ensure_list_of_strings(value: Any, key: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{key} must be a list of strings")
    return value


def build_claude_cmd(
    claude_bin: str,
    model: str,
    permission_mode: str,
    append_args: list[str],
    resume_session_id: str | None,
) -> list[str]:
    cmd = [
        claude_bin,
        "--model",
        model,
        "--print",
        "--verbose",
        "--input-format",
        "text",
        "--output-format",
        "stream-json",
        "--permission-mode",
        permission_mode,
    ]

    if resume_session_id:
        cmd.extend(["--resume", resume_session_id])

    cmd.extend(append_args)
    return cmd


def collect_text_fields(node: Any, output: list[str]) -> None:
    if isinstance(node, dict):
        text_value = node.get("text")
        if isinstance(text_value, str):
            output.append(text_value)

        delta_value = node.get("delta")
        if isinstance(delta_value, str):
            output.append(delta_value)

        for value in node.values():
            collect_text_fields(value, output)
        return

    if isinstance(node, list):
        for item in node:
            collect_text_fields(item, output)


def extract_assistant_text(raw_stdout: str) -> str:
    fragments: list[str] = []

    for line in raw_stdout.splitlines():
        line = line.strip()
        if not line:
            continue

        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            continue

        event_type = parsed.get("type")
        if event_type == "assistant":
            message = parsed.get("message")
            if isinstance(message, dict):
                collect_text_fields(message.get("content"), fragments)
        elif event_type == "result":
            result_text = parsed.get("result")
            if isinstance(result_text, str) and result_text:
                fragments.append(result_text)

    # Dedupe exact consecutive fragments (common in some stream formats).
    deduped: list[str] = []
    for frag in fragments:
        if not deduped or deduped[-1] != frag:
            deduped.append(frag)

    return "".join(deduped).strip()


def extract_stream_metadata(raw_stdout: str) -> dict[str, Any]:
    metadata: dict[str, Any] = {
        "session_id": "",
        "skills": [],
        "slash_commands": [],
    }

    for line in raw_stdout.splitlines():
        line = line.strip()
        if not line:
            continue

        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            continue

        event_type = parsed.get("type")

        if event_type == "system" and parsed.get("subtype") == "init":
            session_id = parsed.get("session_id")
            if isinstance(session_id, str) and session_id:
                metadata["session_id"] = session_id

            skills = parsed.get("skills")
            if isinstance(skills, list) and all(isinstance(item, str) for item in skills):
                metadata["skills"] = list(skills)

            slash_commands = parsed.get("slash_commands")
            if isinstance(slash_commands, list) and all(isinstance(item, str) for item in slash_commands):
                metadata["slash_commands"] = list(slash_commands)

        elif event_type == "result" and not metadata["session_id"]:
            session_id = parsed.get("session_id")
            if isinstance(session_id, str) and session_id:
                metadata["session_id"] = session_id

    return metadata


def run_once(
    prompt: str,
    cwd: Path,
    model: str,
    permission_mode: str,
    timeout_seconds: int,
    append_args: list[str],
    claude_bin: str,
    resume_session_id: str | None = None,
) -> dict[str, Any]:
    cmd = build_claude_cmd(
        claude_bin=claude_bin,
        model=model,
        permission_mode=permission_mode,
        append_args=append_args,
        resume_session_id=resume_session_id,
    )

    started_at = utc_now_iso()
    start_time = time.monotonic()
    timed_out = False

    try:
        process = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError:
        raise RuntimeError(f"Claude binary not found: {claude_bin}")

    try:
        stdout_text, stderr_text = process.communicate(prompt, timeout=timeout_seconds)
        exit_code = process.returncode
    except subprocess.TimeoutExpired:
        process.kill()
        stdout_text, stderr_text = process.communicate()
        exit_code = 124
        timed_out = True

    duration_ms = int((time.monotonic() - start_time) * 1000)
    assistant_text = extract_assistant_text(stdout_text)
    metadata = extract_stream_metadata(stdout_text)

    return {
        "started_at": started_at,
        "duration_ms": duration_ms,
        "timed_out": timed_out,
        "exit_code": exit_code,
        "cmd": cmd,
        "cwd": str(cwd),
        "stdout": stdout_text,
        "stderr": stderr_text,
        "assistant_text": assistant_text,
        "prompt": prompt,
        "resume_session_id": resume_session_id,
        "session_id": metadata.get("session_id", ""),
        "skills": metadata.get("skills", []),
        "slash_commands": metadata.get("slash_commands", []),
    }


def write_run_artifacts(
    result: dict[str, Any],
    output_dir: Path,
    run_name: str,
) -> dict[str, Any]:
    run_dir = output_dir / f"{run_stamp()}-{sanitize_name(run_name)}"
    run_dir.mkdir(parents=True, exist_ok=True)

    prompt_path = run_dir / "prompt.txt"
    stdout_path = run_dir / "stdout.stream.jsonl"
    stderr_path = run_dir / "stderr.txt"
    assistant_path = run_dir / "assistant.txt"
    summary_path = run_dir / "result.json"

    prompt_path.write_text(result["prompt"], encoding="utf-8")
    stdout_path.write_text(result["stdout"], encoding="utf-8")
    stderr_path.write_text(result["stderr"], encoding="utf-8")
    assistant_path.write_text(result["assistant_text"], encoding="utf-8")

    summary = {
        "started_at": result["started_at"],
        "duration_ms": result["duration_ms"],
        "timed_out": result["timed_out"],
        "exit_code": result["exit_code"],
        "cmd": result["cmd"],
        "cwd": result["cwd"],
        "session_id": result["session_id"],
        "resume_session_id": result["resume_session_id"],
        "skills": result["skills"],
        "slash_commands": result["slash_commands"],
        "files": {
            "run_dir": str(run_dir),
            "prompt": str(prompt_path),
            "stdout": str(stdout_path),
            "stderr": str(stderr_path),
            "assistant": str(assistant_path),
            "summary": str(summary_path),
        },
    }

    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def write_turn_artifacts(result: dict[str, Any], turn_dir: Path, turn_index: int) -> dict[str, Any]:
    turn_dir.mkdir(parents=True, exist_ok=True)

    prompt_path = turn_dir / "prompt.txt"
    stdout_path = turn_dir / "stdout.stream.jsonl"
    stderr_path = turn_dir / "stderr.txt"
    assistant_path = turn_dir / "assistant.txt"
    summary_path = turn_dir / "result.json"

    prompt_path.write_text(result["prompt"], encoding="utf-8")
    stdout_path.write_text(result["stdout"], encoding="utf-8")
    stderr_path.write_text(result["stderr"], encoding="utf-8")
    assistant_path.write_text(result["assistant_text"], encoding="utf-8")

    summary = {
        "turn_index": turn_index,
        "started_at": result["started_at"],
        "duration_ms": result["duration_ms"],
        "timed_out": result["timed_out"],
        "exit_code": result["exit_code"],
        "cmd": result["cmd"],
        "cwd": result["cwd"],
        "session_id": result["session_id"],
        "resume_session_id": result["resume_session_id"],
        "skills": result["skills"],
        "slash_commands": result["slash_commands"],
        "files": {
            "turn_dir": str(turn_dir),
            "prompt": str(prompt_path),
            "stdout": str(stdout_path),
            "stderr": str(stderr_path),
            "assistant": str(assistant_path),
            "summary": str(summary_path),
        },
    }

    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary["files"]


def evaluate_case_assertions(
    case_name: str,
    assertions: dict[str, Any],
    result: dict[str, Any],
) -> list[str]:
    errors: list[str] = []

    exit_code_expected = assertions.get("exit_code", 0)
    if not isinstance(exit_code_expected, int):
        raise ValueError("assertions.exit_code must be an integer")
    if result["exit_code"] != exit_code_expected:
        errors.append(
            f"{case_name}: exit_code expected {exit_code_expected}, got {result['exit_code']}"
        )

    if "timed_out" in assertions:
        timed_out_expected = assertions["timed_out"]
        if not isinstance(timed_out_expected, bool):
            raise ValueError("assertions.timed_out must be boolean")
        if result["timed_out"] != timed_out_expected:
            errors.append(
                f"{case_name}: timed_out expected {timed_out_expected}, got {result['timed_out']}"
            )

    assistant_text = result["assistant_text"]
    stdout_text = result["stdout"]
    stderr_text = result["stderr"]

    for needle in ensure_list_of_strings(assertions.get("assistant_contains"), "assertions.assistant_contains"):
        if needle not in assistant_text:
            errors.append(f"{case_name}: assistant text missing substring: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("assistant_not_contains"), "assertions.assistant_not_contains"):
        if needle in assistant_text:
            errors.append(f"{case_name}: assistant text unexpectedly contains: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("stdout_contains"), "assertions.stdout_contains"):
        if needle not in stdout_text:
            errors.append(f"{case_name}: stdout missing substring: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("stdout_not_contains"), "assertions.stdout_not_contains"):
        if needle in stdout_text:
            errors.append(f"{case_name}: stdout unexpectedly contains: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("stderr_contains"), "assertions.stderr_contains"):
        if needle not in stderr_text:
            errors.append(f"{case_name}: stderr missing substring: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("stderr_not_contains"), "assertions.stderr_not_contains"):
        if needle in stderr_text:
            errors.append(f"{case_name}: stderr unexpectedly contains: {needle!r}")

    min_chars = assertions.get("assistant_min_chars")
    if min_chars is not None:
        if not isinstance(min_chars, int):
            raise ValueError("assertions.assistant_min_chars must be an integer")
        if len(assistant_text) < min_chars:
            errors.append(
                f"{case_name}: assistant text too short, expected >= {min_chars}, got {len(assistant_text)}"
            )

    return errors


def evaluate_session_assertions(
    case_name: str,
    assertions: dict[str, Any],
    result: dict[str, Any],
) -> list[str]:
    errors: list[str] = []

    session_id = result.get("session_id", "")
    skills = result.get("skills", [])
    slash_commands = result.get("slash_commands", [])

    if "session_id_present" in assertions:
        expected = assertions["session_id_present"]
        if not isinstance(expected, bool):
            raise ValueError("session_assertions.session_id_present must be boolean")
        is_present = isinstance(session_id, str) and len(session_id) > 0
        if is_present != expected:
            errors.append(
                f"{case_name}: session_id_present expected {expected}, got {is_present}"
            )

    for needle in ensure_list_of_strings(assertions.get("skills_contains"), "session_assertions.skills_contains"):
        if needle not in skills:
            errors.append(f"{case_name}: skills missing entry: {needle!r}")

    for needle in ensure_list_of_strings(assertions.get("skills_not_contains"), "session_assertions.skills_not_contains"):
        if needle in skills:
            errors.append(f"{case_name}: skills unexpectedly contain: {needle!r}")

    for needle in ensure_list_of_strings(
        assertions.get("slash_commands_contains"),
        "session_assertions.slash_commands_contains",
    ):
        if needle not in slash_commands:
            errors.append(f"{case_name}: slash_commands missing entry: {needle!r}")

    for needle in ensure_list_of_strings(
        assertions.get("slash_commands_not_contains"),
        "session_assertions.slash_commands_not_contains",
    ):
        if needle in slash_commands:
            errors.append(f"{case_name}: slash_commands unexpectedly contain: {needle!r}")

    return errors


def resolve_case_path(base_dir: Path, value: str | None) -> Path | None:
    if value is None:
        return None
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = base_dir / path
    return path


def parse_turn_spec(
    turn_data: dict[str, Any],
    case_dir: Path,
    turn_index: int,
) -> dict[str, Any]:
    prompt_inline = turn_data.get("prompt")
    prompt_path_raw = turn_data.get("prompt_file")

    if prompt_inline is not None and not isinstance(prompt_inline, str):
        raise ValueError(f"turns[{turn_index}].prompt must be a string")
    if prompt_path_raw is not None and not isinstance(prompt_path_raw, str):
        raise ValueError(f"turns[{turn_index}].prompt_file must be a string")

    prompt_path = resolve_case_path(case_dir, prompt_path_raw) if prompt_path_raw else None

    assertions = turn_data.get("assertions", {})
    if not isinstance(assertions, dict):
        raise ValueError(f"turns[{turn_index}].assertions must be an object")

    turn_append_args = turn_data.get("append_args", [])
    if not isinstance(turn_append_args, list) or not all(isinstance(item, str) for item in turn_append_args):
        raise ValueError(f"turns[{turn_index}].append_args must be a list of strings")

    timeout_seconds = turn_data.get("timeout_seconds")
    if timeout_seconds is not None and not isinstance(timeout_seconds, int):
        raise ValueError(f"turns[{turn_index}].timeout_seconds must be an integer")

    return {
        "prompt": prompt_inline,
        "prompt_file": str(prompt_path) if prompt_path else None,
        "assertions": assertions,
        "append_args": turn_append_args,
        "timeout_seconds": timeout_seconds,
    }


def normalize_case_turns(case_data: dict[str, Any], case_dir: Path) -> tuple[list[dict[str, Any]], bool]:
    turns_raw = case_data.get("turns")

    if turns_raw is not None:
        if not isinstance(turns_raw, list) or len(turns_raw) == 0:
            raise ValueError("turns must be a non-empty array")

        turns: list[dict[str, Any]] = []
        for index, turn_data in enumerate(turns_raw, start=1):
            if not isinstance(turn_data, dict):
                raise ValueError(f"turns[{index}] must be an object")
            turns.append(parse_turn_spec(turn_data, case_dir, index))

        return turns, True

    # Backward-compatible single-turn format.
    single_turn = parse_turn_spec(
        {
            "prompt": case_data.get("prompt"),
            "prompt_file": case_data.get("prompt_file"),
            "assertions": case_data.get("assertions", {}),
            "append_args": case_data.get("append_args", []),
            "timeout_seconds": case_data.get("timeout_seconds"),
        },
        case_dir,
        1,
    )
    return [single_turn], False


def run_case(case_file: Path, output_dir: Path, claude_bin: str) -> int:
    if not case_file.is_file():
        raise ValueError(f"Case file not found: {case_file}")

    case_data = json.loads(case_file.read_text(encoding="utf-8"))
    if not isinstance(case_data, dict):
        raise ValueError("Case file root must be an object")

    case_name = str(case_data.get("name") or case_file.stem)
    case_dir = case_file.parent

    model = str(case_data.get("model", "sonnet"))
    permission_mode = str(case_data.get("permission_mode", "bypassPermissions"))
    timeout_seconds = int(case_data.get("timeout_seconds", 180))

    global_append_args = case_data.get("append_args", [])
    if not isinstance(global_append_args, list) or not all(isinstance(item, str) for item in global_append_args):
        raise ValueError("append_args must be a list of strings")

    session_assertions = case_data.get("session_assertions", {})
    if not isinstance(session_assertions, dict):
        raise ValueError("session_assertions must be an object")

    turns, has_turns_field = normalize_case_turns(case_data, case_dir)

    final_assertions: dict[str, Any] = {}
    if has_turns_field:
        raw_final_assertions = case_data.get("assertions", {})
        if not isinstance(raw_final_assertions, dict):
            raise ValueError("assertions must be an object")
        final_assertions = raw_final_assertions

    cwd_raw = case_data.get("cwd")
    if cwd_raw is None:
        cwd = case_dir
    elif not isinstance(cwd_raw, str):
        raise ValueError("cwd must be a string")
    else:
        cwd_path = resolve_case_path(case_dir, cwd_raw)
        assert cwd_path is not None
        cwd = cwd_path

    if not cwd.exists() or not cwd.is_dir():
        raise ValueError(f"Case cwd must be an existing directory: {cwd}")

    case_run_dir = output_dir / f"{run_stamp()}-{sanitize_name(case_name)}"
    case_run_dir.mkdir(parents=True, exist_ok=True)

    errors: list[str] = []
    turn_summaries: list[dict[str, Any]] = []
    session_id = ""
    last_result: dict[str, Any] | None = None

    for index, turn in enumerate(turns, start=1):
        turn_prompt = load_prompt(turn.get("prompt"), turn.get("prompt_file"))

        turn_timeout = turn.get("timeout_seconds")
        effective_timeout = turn_timeout if isinstance(turn_timeout, int) else timeout_seconds

        turn_append_args = global_append_args + ensure_list_of_strings(
            turn.get("append_args"),
            f"turns[{index}].append_args",
        )

        resume_session_id = session_id if index > 1 and session_id else None

        raw_result = run_once(
            prompt=turn_prompt,
            cwd=cwd,
            model=model,
            permission_mode=permission_mode,
            timeout_seconds=effective_timeout,
            append_args=turn_append_args,
            claude_bin=claude_bin,
            resume_session_id=resume_session_id,
        )

        current_session_id = str(raw_result.get("session_id", ""))
        if index == 1 and current_session_id:
            session_id = current_session_id
        elif resume_session_id and current_session_id and current_session_id != resume_session_id:
            errors.append(
                f"{case_name}: turn {index} resumed session {resume_session_id} but received session_id {current_session_id}"
            )

        turn_dir = case_run_dir / f"turn-{index:02d}"
        files = write_turn_artifacts(raw_result, turn_dir, index)

        turn_summaries.append(
            {
                "turn_index": index,
                "exit_code": raw_result["exit_code"],
                "timed_out": raw_result["timed_out"],
                "duration_ms": raw_result["duration_ms"],
                "session_id": current_session_id,
                "files": files,
            }
        )

        turn_assertions = turn.get("assertions", {})
        errors.extend(evaluate_case_assertions(f"{case_name} turn {index}", turn_assertions, raw_result))

        if index == 1 and session_assertions:
            errors.extend(evaluate_session_assertions(case_name, session_assertions, raw_result))

        last_result = raw_result

    if has_turns_field and final_assertions and last_result is not None:
        errors.extend(evaluate_case_assertions(f"{case_name} final", final_assertions, last_result))

    case_summary_path = case_run_dir / "result.json"
    case_summary = {
        "name": case_name,
        "model": model,
        "permission_mode": permission_mode,
        "cwd": str(cwd),
        "turn_count": len(turn_summaries),
        "session_id": session_id,
        "errors": errors,
        "turns": turn_summaries,
    }
    case_summary_path.write_text(json.dumps(case_summary, indent=2), encoding="utf-8")

    if errors:
        print(f"FAIL: {case_name}")
        for err in errors:
            print(f"  - {err}")
        print(f"  artifacts: {case_run_dir}")
        return 1

    print(f"PASS: {case_name}")
    print(f"  artifacts: {case_run_dir}")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    prompt = load_prompt(args.prompt, args.prompt_file)

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise ValueError(f"cwd must be an existing directory: {cwd}")

    raw_result = run_once(
        prompt=prompt,
        cwd=cwd,
        model=args.model,
        permission_mode=args.permission_mode,
        timeout_seconds=args.timeout_seconds,
        append_args=args.append_args,
        claude_bin=args.claude_bin,
        resume_session_id=args.resume_session_id,
    )

    summary = write_run_artifacts(raw_result, Path(args.output_dir).expanduser(), args.run_name)
    print(json.dumps(summary, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Claude skill testing harness")
    subparsers = parser.add_subparsers(dest="command", required=True)

    run_parser = subparsers.add_parser("run", help="Run one prompt via claude --print")
    run_parser.add_argument("--prompt", help="Inline prompt text")
    run_parser.add_argument("--prompt-file", help="Path to prompt file")
    run_parser.add_argument("--cwd", default=".", help="Working directory for claude")
    run_parser.add_argument("--model", default="sonnet", help="Claude model alias/name")
    run_parser.add_argument(
        "--permission-mode",
        default="bypassPermissions",
        help="Claude permission mode (default: bypassPermissions)",
    )
    run_parser.add_argument("--timeout-seconds", type=int, default=180, help="Command timeout in seconds")
    run_parser.add_argument(
        "--append-args",
        nargs="*",
        default=[],
        help="Extra args appended to claude command",
    )
    run_parser.add_argument("--resume-session-id", default=None, help="Resume an existing Claude session ID")
    run_parser.add_argument("--claude-bin", default="claude", help="Claude CLI path")
    run_parser.add_argument(
        "--output-dir",
        default=".responses/claude-skill-harness",
        help="Artifact output directory",
    )
    run_parser.add_argument("--run-name", default="manual", help="Run name used in artifact folder")

    case_parser = subparsers.add_parser("case", help="Run one JSON case and evaluate assertions")
    case_parser.add_argument("--case-file", required=True, help="Path to JSON case file")
    case_parser.add_argument("--claude-bin", default="claude", help="Claude CLI path")
    case_parser.add_argument(
        "--output-dir",
        default=".responses/claude-skill-harness",
        help="Artifact output directory",
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "run":
        return cmd_run(args)

    if args.command == "case":
        return run_case(
            case_file=Path(args.case_file).expanduser().resolve(),
            output_dir=Path(args.output_dir).expanduser(),
            claude_bin=args.claude_bin,
        )

    raise ValueError(f"Unknown command: {args.command}")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, json.JSONDecodeError) as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)
