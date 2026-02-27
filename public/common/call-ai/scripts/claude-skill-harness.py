#!/usr/bin/env python3
"""Compatibility wrapper for shared Claude skill harness.

Canonical script:
  scripts/claude-skill-e2e/claude-skill-harness.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[4]
TARGET = REPO_ROOT / "scripts" / "claude-skill-e2e" / "claude-skill-harness.py"

if not TARGET.is_file():
    print(f"Error: shared harness not found: {TARGET}", file=sys.stderr)
    sys.exit(1)

os.execv(sys.executable, [sys.executable, str(TARGET), *sys.argv[1:]])
