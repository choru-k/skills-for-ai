#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
TARGET="$REPO_ROOT/scripts/claude-skill-e2e/test-claude-skills.sh"

if [[ ! -x "$TARGET" ]]; then
  echo "Error: shared runner not found or not executable: $TARGET" >&2
  exit 1
fi

exec "$TARGET" "$@"
