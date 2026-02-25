#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="$SCRIPT_DIR/test-front-compaction-core.ts"

if ! command -v bun >/dev/null 2>&1; then
  echo "Error: bun is required to run Pi front-compaction tests" >&2
  exit 1
fi

bun "$TEST_FILE"
