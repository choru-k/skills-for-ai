#!/usr/bin/env python3
"""Negative scenario validation for drift/private-leak checks."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def run_capture(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def fail(message: str, output: str = "") -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    if output:
        print(output, file=sys.stderr)
    return 1


def mutate_drift_package(repo: Path) -> None:
    path = repo / "package.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    skills = data.get("pi", {}).get("skills")
    if not isinstance(skills, list) or len(skills) < 2:
        raise RuntimeError("pi.skills must contain at least two entries for drift simulation")
    skills[0], skills[1] = skills[1], skills[0]
    path.write_text(f"{json.dumps(data, indent=2, ensure_ascii=False)}\n", encoding="utf-8")


def mutate_private_leak_package(repo: Path) -> None:
    path = repo / "package.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    skills = data.get("pi", {}).get("skills")
    if not isinstance(skills, list):
        raise RuntimeError("pi.skills must be an array")

    leak_path = "private/common/work-ticket/SKILL.md"
    if leak_path not in skills:
        skills.append(leak_path)

    path.write_text(f"{json.dumps(data, indent=2, ensure_ascii=False)}\n", encoding="utf-8")


def main() -> int:
    print("[1/3] Baseline public contract check")
    baseline = run_capture([sys.executable, "scripts/check-public-output-drift.py"], REPO_ROOT)
    if baseline.returncode != 0:
        return fail("baseline public contract check failed", baseline.stdout + baseline.stderr)

    print("[2/3] Drift scenario (expected failure with exit code 4)")
    with tempfile.TemporaryDirectory() as tmp:
        drift_repo = Path(tmp) / "drift"
        shutil.copytree(REPO_ROOT, drift_repo, symlinks=True)

        try:
            mutate_drift_package(drift_repo)
        except RuntimeError as exc:
            return fail(str(exc))

        drift = run_capture(
            [sys.executable, "scripts/sync-catalog-artifacts.py", "--check", "--lane", "public"],
            drift_repo,
        )
        drift_output = drift.stdout + drift.stderr

        if drift.returncode == 0:
            return fail("drift scenario unexpectedly passed", drift_output)
        if drift.returncode != 4:
            return fail(f"expected drift exit code 4, got {drift.returncode}", drift_output)
        if "DRIFT " not in drift_output:
            return fail("expected DRIFT output in drift scenario", drift_output)

    print("[3/3] Private leak scenario (expected failure)")
    with tempfile.TemporaryDirectory() as tmp:
        leak_repo = Path(tmp) / "leak"
        shutil.copytree(REPO_ROOT, leak_repo, symlinks=True)

        try:
            mutate_private_leak_package(leak_repo)
        except RuntimeError as exc:
            return fail(str(exc))

        leak = run_capture([sys.executable, "scripts/check-private-leaks.py"], leak_repo)
        leak_output = leak.stdout + leak.stderr

        if leak.returncode == 0:
            return fail("private leak scenario unexpectedly passed", leak_output)
        if not re.search(r"non-public path leaked|non-public source leaked", leak_output):
            return fail("expected private-leak failure output", leak_output)

    print("contract scenario validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
