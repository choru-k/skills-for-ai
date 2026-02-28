#!/usr/bin/env bash
set -euo pipefail

resolve_path() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).expanduser().resolve())
PY
}

resolve_dotfiles_root() {
  if [[ -n "${DOTFILES_ROOT:-}" ]]; then
    printf '%s\n' "$(resolve_path "$DOTFILES_ROOT")"
    return
  fi

  local runtime_settings="$HOME/.pi/agent/settings.json"
  if [[ -e "$runtime_settings" || -L "$runtime_settings" ]]; then
    local resolved
    resolved="$(resolve_path "$runtime_settings")"
    local candidate
    candidate="$(resolve_path "$(dirname "$resolved")/..")"
    if [[ -f "$candidate/pi/settings.json" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  fi

  if [[ -f "$HOME/dotfiles/pi/settings.json" ]]; then
    printf '%s\n' "$(resolve_path "$HOME/dotfiles")"
    return
  fi

  echo "[FAIL] could not resolve dotfiles root (set DOTFILES_ROOT)" >&2
  exit 1
}

DOTFILES_DIR="$(resolve_dotfiles_root)"
SETTINGS_FILE="$DOTFILES_DIR/pi/settings.json"
README_FILE="$DOTFILES_DIR/pi/README.md"

failures=0

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  failures=$((failures + 1))
}

check_extension_enabled() {
  local extension="$1"
  local label="$2"

  if jq -r '.extensions[]' "$SETTINGS_FILE" | rg -q "${extension}"; then
    pass "$label enabled"
  else
    fail "$label missing in pi/settings.json"
  fi
}

check_readme_anchor() {
  local pattern="$1"
  local label="$2"

  if rg -q "$pattern" "$README_FILE"; then
    pass "$label documented"
  else
    fail "$label missing in pi/README.md"
  fi
}

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "[FAIL] settings file not found: $SETTINGS_FILE"
  exit 1
fi

if [ ! -f "$README_FILE" ]; then
  echo "[FAIL] README file not found: $README_FILE"
  exit 1
fi

check_extension_enabled "dynamic-session-title/extension\\.ts" "dynamic session title extension"
check_extension_enabled "session-resume-summary/extension\\.ts" "session resume summary extension"

check_readme_anchor "dynamic-session-title/extension\\.ts" "dynamic session title extension"
check_readme_anchor "session-resume-summary/extension\\.ts" "session resume summary extension"
check_readme_anchor "/session-title-status" "session-title-status command"
check_readme_anchor "/session-summary-status" "session-summary-status command"
check_readme_anchor "/session-resume-status" "session-resume-status command"
check_readme_anchor "pi-resume-validate" "pi-resume-validate command"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "Resume workflow validation failed: $failures issue(s)"
  exit 1
fi

echo ""
echo "All resume workflow checks passed."
