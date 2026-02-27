#!/usr/bin/env bash
# Runner router for call-ai.
# Selects the best available execution path for the current environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

is_ghostty() {
  [[ "${TERM_PROGRAM:-}" == "ghostty" ]] || [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]
}

if [[ -n "${ZELLIJ:-}" ]]; then
  exec "$SCRIPT_DIR/ask-ai-zellij.sh" "$@"
fi

if [[ -n "${TMUX:-}" && -x "$SCRIPT_DIR/ask-ai-tmux.sh" ]]; then
  exec "$SCRIPT_DIR/ask-ai-tmux.sh" "$@"
fi

if is_ghostty && [[ -x "$SCRIPT_DIR/ask-ai-ghostty.sh" ]]; then
  exec "$SCRIPT_DIR/ask-ai-ghostty.sh" "$@"
fi

exec "$SCRIPT_DIR/ask-ai.sh" "$@"
