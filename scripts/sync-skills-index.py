#!/usr/bin/env python3
"""Sync skills/ symlink index from package.json#pi.skills.

Rules:
- pi.skills entries under plugins/** become symlinks in skills/<skill-name>
- pi.skills entries under skills/** are treated as direct in-place skill directories
- stale plugin-backed symlinks in skills/ are removed
- non-plugin entries in skills/ are left untouched
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_JSON = REPO_ROOT / "package.json"
SKILLS_DIR = REPO_ROOT / "skills"
PLUGINS_DIR = REPO_ROOT / "plugins"


@dataclass(frozen=True)
class Action:
    kind: str  # "upsert" | "remove"
    link_path: Path
    link_target: str = ""


def rel(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def load_pi_skill_paths() -> list[Path]:
    if not PACKAGE_JSON.exists():
        raise RuntimeError(f"Missing {rel(PACKAGE_JSON)}")

    data = json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))
    skills = data.get("pi", {}).get("skills")
    if not isinstance(skills, list):
        raise RuntimeError("package.json missing array field: pi.skills")

    result: list[Path] = []
    for raw in skills:
        if not isinstance(raw, str):
            raise RuntimeError(f"pi.skills entries must be strings, got: {raw!r}")
        p = Path(raw)
        if p.is_absolute():
            raise RuntimeError(f"pi.skills path must be relative: {raw}")
        abs_path = REPO_ROOT / p
        if not abs_path.exists():
            raise RuntimeError(f"pi.skills path does not exist: {raw}")
        if abs_path.name != "SKILL.md":
            raise RuntimeError(f"pi.skills path must point to SKILL.md: {raw}")
        result.append(p)

    return result


def build_expected_plugin_links(pi_skill_paths: list[Path]) -> dict[str, Path]:
    expected: dict[str, Path] = {}

    for path in pi_skill_paths:
        if not path.parts or path.parts[0] != "plugins":
            continue

        skill_dir = (REPO_ROOT / path).parent
        skill_name = skill_dir.name

        existing = expected.get(skill_name)
        if existing and existing.resolve() != skill_dir.resolve():
            raise RuntimeError(
                "Duplicate plugin-backed skill name in pi.skills: "
                f"{skill_name} -> {rel(existing)} and {rel(skill_dir)}"
            )

        expected[skill_name] = skill_dir

    return expected


def is_plugin_backed_symlink(path: Path) -> bool:
    if not path.is_symlink():
        return False

    target = (path.parent / os.readlink(path)).resolve()
    try:
        target.relative_to(PLUGINS_DIR)
        return True
    except ValueError:
        return False


def plan_actions(expected_links: dict[str, Path]) -> list[Action]:
    actions: list[Action] = []

    for skill_name, target_dir in sorted(expected_links.items()):
        link_path = SKILLS_DIR / skill_name
        link_target = os.path.relpath(target_dir, SKILLS_DIR)
        target_resolved = target_dir.resolve()

        if link_path.exists() or link_path.is_symlink():
            if link_path.is_symlink():
                current_raw = os.readlink(link_path)
                current_resolved = (link_path.parent / current_raw).resolve()
                if current_resolved != target_resolved or current_raw != link_target:
                    actions.append(Action(kind="upsert", link_path=link_path, link_target=link_target))
            else:
                raise RuntimeError(
                    f"Expected symlink at {rel(link_path)} for plugin skill '{skill_name}', "
                    "but found regular file/directory"
                )
        else:
            actions.append(Action(kind="upsert", link_path=link_path, link_target=link_target))

    expected_names = set(expected_links.keys())
    for entry in sorted(SKILLS_DIR.iterdir()):
        if not is_plugin_backed_symlink(entry):
            continue
        if entry.name not in expected_names:
            actions.append(Action(kind="remove", link_path=entry))

    return actions


def apply_actions(actions: list[Action]) -> None:
    for action in actions:
        if action.kind == "upsert":
            if action.link_path.exists() or action.link_path.is_symlink():
                action.link_path.unlink()
            action.link_path.symlink_to(action.link_target)
            print(f"linked  {rel(action.link_path)} -> {action.link_target}")
        elif action.kind == "remove":
            action.link_path.unlink()
            print(f"removed {rel(action.link_path)}")
        else:
            raise RuntimeError(f"Unknown action kind: {action.kind}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync skills/ symlink index from package.json#pi.skills")
    parser.add_argument("--check", action="store_true", help="Do not modify files; fail if changes are needed")
    args = parser.parse_args()

    if not SKILLS_DIR.is_dir():
        raise RuntimeError(f"Missing skills directory: {rel(SKILLS_DIR)}")

    pi_skill_paths = load_pi_skill_paths()
    expected_links = build_expected_plugin_links(pi_skill_paths)
    actions = plan_actions(expected_links)

    if not actions:
        print("skills index already in sync")
        return 0

    if args.check:
        print("skills index is out of sync:")
        for action in actions:
            if action.kind == "upsert":
                print(f"  - link  {rel(action.link_path)} -> {action.link_target}")
            else:
                print(f"  - remove {rel(action.link_path)}")
        return 1

    apply_actions(actions)
    print("skills index sync complete")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
