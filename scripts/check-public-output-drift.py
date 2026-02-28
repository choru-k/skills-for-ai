#!/usr/bin/env python3
"""Public-output drift guardrail."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    result = subprocess.run(
        [sys.executable, "scripts/sync-catalog-artifacts.py", "--check", "--lane", "public"],
        cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        return result.returncode

    print("public-output drift checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
