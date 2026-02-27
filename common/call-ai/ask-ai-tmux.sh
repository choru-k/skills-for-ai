#!/usr/bin/env bash
# tmux runner placeholder.
# For now this uses the headless runner; tmux pane orchestration is added later.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TMUX:-}" ]]; then
  exec "$SCRIPT_DIR/ask-ai.sh" "$@"
fi

exec "$SCRIPT_DIR/ask-ai.sh" "$@"
