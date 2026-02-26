#!/usr/bin/env bash
# Ghostty runner placeholder.
# For now this uses the headless runner; native Ghostty pane orchestration is added later.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

is_ghostty() {
  [[ "${TERM_PROGRAM:-}" == "ghostty" ]] || [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]
}

if ! is_ghostty; then
  exec "$SCRIPT_DIR/ask-ai.sh" "$@"
fi

exec "$SCRIPT_DIR/ask-ai.sh" "$@"
