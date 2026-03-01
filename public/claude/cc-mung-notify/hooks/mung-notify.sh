#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_JSON="$(cat || true)"

is_truthy() {
  local value
  value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" || "$value" == "on" ]]
}

debug() {
  if is_truthy "${CLAUDE_MUNG_DEBUG:-0}"; then
    echo "[claude-mung-notify] $*" >&2
  fi
}

normalize_text() {
  local raw="${1:-}"
  printf '%s' "$raw" \
    | tr '\r\n\t' '   ' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

truncate_text() {
  local text="${1:-}"
  local max_length="${2:-220}"

  python3 - "$text" "$max_length" <<'PY'
import sys

text = sys.argv[1]
max_length = int(sys.argv[2])

if len(text) <= max_length:
    sys.stdout.write(text)
else:
    sys.stdout.write(text[:max(0, max_length - 1)] + "…")
PY
}

shell_escape() {
  local value="${1:-}"
  python3 - "$value" <<'PY'
import shlex
import sys

print(shlex.quote(sys.argv[1]))
PY
}

json_get() {
  local key_path="$1"
  local default_value="${2:-}"

  python3 - "$key_path" "$default_value" "$INPUT_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
default = sys.argv[2]
raw = sys.argv[3]

if not raw.strip():
    sys.stdout.write(default)
    raise SystemExit(0)

try:
    data = json.loads(raw)
except Exception:
    sys.stdout.write(default)
    raise SystemExit(0)

value = data
for part in path.split('.'):
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        sys.stdout.write(default)
        raise SystemExit(0)

if value is None:
    sys.stdout.write(default)
elif isinstance(value, bool):
    sys.stdout.write("true" if value else "false")
elif isinstance(value, (int, float, str)):
    sys.stdout.write(str(value))
else:
    sys.stdout.write(default)
PY
}

resolve_bin() {
  local preferred="$1"
  shift || true

  if [[ -x "$preferred" ]]; then
    echo "$preferred"
    return 0
  fi

  for candidate in "$@"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  echo ""
}

resolve_mung_command() {
  local -a candidates=()

  if [[ -n "${CLAUDE_MUNG_COMMAND:-}" ]]; then
    candidates+=("${CLAUDE_MUNG_COMMAND}")
  fi

  candidates+=("mung" "/opt/homebrew/bin/mung")

  local candidate=""
  local resolved=""

  for candidate in "${candidates[@]}"; do
    [[ -z "$candidate" ]] && continue

    if [[ "$candidate" == */* ]]; then
      [[ -x "$candidate" ]] || continue
      resolved="$candidate"
    else
      resolved="$(command -v "$candidate" 2>/dev/null || true)"
      [[ -n "$resolved" ]] || continue
    fi

    if "$resolved" version >/dev/null 2>&1; then
      printf '%s' "$resolved"
      return 0
    fi
  done

  return 1
}

try_mung() {
  local mung_command="$1"
  shift

  if ! "$mung_command" "$@" >/dev/null 2>&1; then
    debug "mung command failed: $mung_command $*"
    return 1
  fi

  return 0
}

extract_last_assistant_text() {
  local transcript_path="$1"
  local fallback_message="$2"

  python3 - "$transcript_path" "$fallback_message" <<'PY'
import json
import os
import re
import sys

transcript_path = sys.argv[1]
fallback = sys.argv[2]


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


last_text = ""

if transcript_path and os.path.exists(transcript_path):
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue

                try:
                    event = json.loads(line)
                except Exception:
                    continue

                if event.get("type") != "assistant":
                    continue

                message = event.get("message")
                if not isinstance(message, dict):
                    continue

                content = message.get("content")
                candidate = ""

                if isinstance(content, str):
                    candidate = content
                elif isinstance(content, list):
                    parts = []
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get("type") != "text":
                            continue
                        text = block.get("text")
                        if isinstance(text, str):
                            parts.append(text)

                    candidate = " ".join(parts)

                candidate = normalize(candidate)
                if candidate:
                    last_text = candidate
    except Exception:
        pass

sys.stdout.write(last_text or fallback)
PY
}

normalize_zellij_pane_id() {
  local raw_pane_id="${1:-}"
  local pane_id
  pane_id="$(normalize_text "$raw_pane_id")"

  if [[ -z "$pane_id" ]]; then
    return 0
  fi

  if [[ "$pane_id" == terminal_* || "$pane_id" == plugin_* ]]; then
    printf '%s' "$pane_id"
    return 0
  fi

  if [[ "$pane_id" =~ ^[0-9]+$ ]]; then
    printf 'terminal_%s' "$pane_id"
    return 0
  fi

  printf '%s' "$pane_id"
}

normalize_tmux_pane_id() {
  local raw_pane_id="${1:-}"
  local pane_id
  pane_id="$(normalize_text "$raw_pane_id")"

  if [[ -z "$pane_id" ]]; then
    return 0
  fi

  if [[ "$pane_id" == %* ]]; then
    printf '%s' "$pane_id"
    return 0
  fi

  if [[ "$pane_id" =~ ^[0-9]+$ ]]; then
    printf '%%%s' "$pane_id"
    return 0
  fi

  printf '%s' "$pane_id"
}

detect_terminal_program() {
  local forced_terminal=""
  local term_program=""

  forced_terminal="$(normalize_text "${CLAUDE_MUNG_TERMINAL:-}")"
  forced_terminal="$(printf '%s' "$forced_terminal" | tr '[:upper:]' '[:lower:]')"

  if [[ "$forced_terminal" == "wezterm" || "$forced_terminal" == "ghostty" ]]; then
    printf '%s' "$forced_terminal"
    return 0
  fi

  term_program="$(normalize_text "${TERM_PROGRAM:-}")"
  term_program="$(printf '%s' "$term_program" | tr '[:upper:]' '[:lower:]')"

  if [[ "$term_program" == *"wezterm"* ]]; then
    printf 'wezterm'
    return 0
  fi

  if [[ "$term_program" == *"ghostty"* ]]; then
    printf 'ghostty'
    return 0
  fi

  if [[ -n "$(normalize_text "${WEZTERM_PANE:-}")" ]]; then
    printf 'wezterm'
    return 0
  fi

  if [[ -n "$(normalize_text "${GHOSTTY_BIN_DIR:-}")" || -n "$(normalize_text "${GHOSTTY_RESOURCES_DIR:-}")" ]]; then
    printf 'ghostty'
    return 0
  fi
}

detect_ghostty_tab_mode() {
  local raw_mode
  raw_mode="$(normalize_text "${CLAUDE_MUNG_GHOSTTY_TAB_MODE:-}")"
  raw_mode="$(printf '%s' "$raw_mode" | tr '[:upper:]' '[:lower:]')"

  if [[ "$raw_mode" == "single" || "$raw_mode" == "multi" || "$raw_mode" == "unknown" ]]; then
    printf '%s' "$raw_mode"
    return 0
  fi

  printf 'unknown'
}

resolve_focused_zellij_tab_index() {
  local session_name="$1"
  local zellij_bin=""
  local output=""

  [[ -n "$session_name" ]] || return 0

  zellij_bin="${ZELLIJ_BIN:-$(resolve_bin /opt/homebrew/bin/zellij zellij)}"
  [[ -n "$zellij_bin" ]] || return 0

  output="$("$zellij_bin" -s "$session_name" action dump-layout 2>/dev/null || true)"
  [[ -n "$output" ]] || return 0

  local tab_index=0
  local line=""

  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[[:space:]]*tab[[:space:]]name= ]]; then
      continue
    fi

    tab_index=$((tab_index + 1))
    if [[ "$line" == *"focus=true"* ]]; then
      printf '%s' "$tab_index"
      return 0
    fi
  done <<<"$output"
}

FOCUS_ON_CLICK_COMMAND=""
FOCUS_TIER=""

build_focus_decision() {
  FOCUS_ON_CLICK_COMMAND=""
  FOCUS_TIER=""

  local focus_script_path="$1"
  if [[ ! -x "$focus_script_path" ]]; then
    debug "focus script missing or not executable: $focus_script_path"
    return 0
  fi

  local terminal_program=""
  local wezterm_pane_id=""
  local zellij_session_name=""
  local zellij_pane_id=""
  local tmux_session_name=""
  local tmux_window_index=""
  local tmux_pane_id=""

  terminal_program="$(detect_terminal_program)"
  wezterm_pane_id="$(normalize_text "${WEZTERM_PANE:-}")"
  zellij_session_name="$(normalize_text "${ZELLIJ_SESSION_NAME:-}")"
  zellij_pane_id="$(normalize_zellij_pane_id "${ZELLIJ_PANE_ID:-}")"
  tmux_session_name="$(normalize_text "${CLAUDE_MUNG_TMUX_SESSION:-${TMUX_SESSION:-}}")"
  tmux_window_index="$(normalize_text "${CLAUDE_MUNG_TMUX_WINDOW:-${TMUX_WINDOW:-}}")"
  tmux_pane_id="$(normalize_tmux_pane_id "${CLAUDE_MUNG_TMUX_PANE:-${TMUX_PANE:-}}")"

  local has_terminal_activation=0
  local has_wezterm_pane=0
  local has_zellij_target=0
  local has_tmux_target=0
  local has_mux_target=0

  [[ -n "$terminal_program" ]] && has_terminal_activation=1
  [[ -n "$wezterm_pane_id" ]] && has_wezterm_pane=1
  if [[ -n "$zellij_session_name" || -n "$zellij_pane_id" ]]; then
    has_zellij_target=1
  fi
  if [[ -n "$tmux_session_name" || -n "$tmux_window_index" || -n "$tmux_pane_id" ]]; then
    has_tmux_target=1
  fi
  if [[ "$has_zellij_target" -eq 1 || "$has_tmux_target" -eq 1 ]]; then
    has_mux_target=1
  fi

  if [[ "$has_terminal_activation" -eq 0 && "$has_wezterm_pane" -eq 0 && "$has_mux_target" -eq 0 ]]; then
    return 0
  fi

  local tier="best_effort"

  if [[ "$terminal_program" == "wezterm" || ( -z "$terminal_program" && "$has_wezterm_pane" -eq 1 ) ]]; then
    if [[ "$has_wezterm_pane" -eq 1 ]]; then
      tier="exact"
    elif [[ "$has_mux_target" -eq 1 ]]; then
      tier="best_effort"
    else
      tier="app_only"
    fi
  elif [[ "$terminal_program" == "ghostty" ]]; then
    if [[ "$has_mux_target" -eq 0 ]]; then
      tier="app_only"
    else
      case "$(detect_ghostty_tab_mode)" in
        single)
          tier="practical_exact"
          ;;
        multi|unknown)
          tier="best_effort"
          ;;
      esac
    fi
  elif [[ "$has_mux_target" -eq 1 ]]; then
    tier="best_effort"
  else
    tier="app_only"
  fi

  local zellij_tab_index=""
  if [[ -n "$zellij_session_name" ]]; then
    zellij_tab_index="$(resolve_focused_zellij_tab_index "$zellij_session_name")"
  fi

  local script_command=""
  script_command="$(shell_escape "$focus_script_path")"
  script_command+=" $(shell_escape "$terminal_program")"
  script_command+=" $(shell_escape "$wezterm_pane_id")"
  script_command+=" $(shell_escape "$zellij_session_name")"
  script_command+=" $(shell_escape "$zellij_tab_index")"
  script_command+=" $(shell_escape "$zellij_pane_id")"
  script_command+=" $(shell_escape "$tmux_session_name")"
  script_command+=" $(shell_escape "$tmux_window_index")"
  script_command+=" $(shell_escape "$tmux_pane_id")"

  FOCUS_ON_CLICK_COMMAND="bash -lc $(shell_escape "$script_command")"
  FOCUS_TIER="$tier"
}

clear_session_alerts() {
  local mung_command="$1"
  try_mung "$mung_command" clear \
    --source "$MUNG_SOURCE" \
    --session "$SESSION_ID" || true
}

clear_session_action_alerts() {
  local mung_command="$1"
  try_mung "$mung_command" clear \
    --source "$MUNG_SOURCE" \
    --session "$SESSION_ID" \
    --kind "$MUNG_KIND_ACTION" || true
}

send_mung_notification() {
  local mung_command="$1"
  local title="$2"
  local message="$3"
  local icon="$4"
  local kind="$5"
  local dedupe_key="$6"
  local on_click_command="$7"
  shift 7
  local -a extra_tags=("$@")

  local normalized_title=""
  local normalized_message=""
  normalized_title="$(truncate_text "$(normalize_text "$title")" 80)"
  normalized_message="$(truncate_text "$(normalize_text "$message")" 220)"

  local -a args=(
    add
    --title "$normalized_title"
    --message "$normalized_message"
    --source "$MUNG_SOURCE"
    --session "$SESSION_ID"
    --kind "$kind"
    --dedupe-key "$dedupe_key"
    --icon "$icon"
    --sound "$MUNG_SOUND"
  )

  local -a unique_tags=()
  local tag=""
  local normalized_tag=""
  local existing_tag=""
  local exists=0

  for tag in "$MUNG_TAG" "${extra_tags[@]}"; do
    normalized_tag="$(normalize_text "$tag")"
    [[ -n "$normalized_tag" ]] || continue

    exists=0
    for existing_tag in "${unique_tags[@]}"; do
      if [[ "$existing_tag" == "$normalized_tag" ]]; then
        exists=1
        break
      fi
    done

    if [[ "$exists" -eq 0 ]]; then
      unique_tags+=("$normalized_tag")
    fi
  done

  for tag in "${unique_tags[@]}"; do
    args+=(--tag "$tag")
  done

  if [[ -n "$on_click_command" ]]; then
    args+=(--on-click "$on_click_command")
  fi

  try_mung "$mung_command" "${args[@]}" || true
}

HOOK_EVENT_NAME="$(normalize_text "$(json_get hook_event_name)")"
if [[ -z "$HOOK_EVENT_NAME" ]]; then
  exit 0
fi

SESSION_ID="$(normalize_text "$(json_get session_id)")"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="unknown"
fi

MUNG_SOURCE="$(normalize_text "${CLAUDE_MUNG_SOURCE:-claude-code}")"
if [[ -z "$MUNG_SOURCE" ]]; then
  MUNG_SOURCE="claude-code"
fi

MUNG_TAG="$MUNG_SOURCE"
MUNG_SESSION_TAG_PREFIX="${CLAUDE_MUNG_SESSION_TAG_PREFIX:-cc-session-}"
MUNG_ACTION_TAG="${CLAUDE_MUNG_ACTION_TAG:-cc-needs-action}"
MUNG_FOCUS_TIER_TAG_PREFIX="${CLAUDE_MUNG_FOCUS_TIER_TAG_PREFIX:-cc-focus-tier-}"
MUNG_KIND_UPDATE="update"
MUNG_KIND_ACTION="action"
MUNG_SOUND="${CLAUDE_MUNG_SOUND:-default}"
ACTION_ICON="${CLAUDE_MUNG_ACTION_ICON:-🦴}"
UPDATE_ICON="${CLAUDE_MUNG_UPDATE_ICON:-🦴}"
DEFAULT_ACTION_TITLE="${CLAUDE_MUNG_ACTION_TITLE:-Claude needs your confirmation}"
DEFAULT_ACTION_MESSAGE="${CLAUDE_MUNG_ACTION_MESSAGE:-Claude needs your input in the current session.}"
DEFAULT_UPDATE_TITLE="${CLAUDE_MUNG_UPDATE_TITLE:-Claude task update}"
DEFAULT_UPDATE_MESSAGE="${CLAUDE_MUNG_UPDATE_MESSAGE:-Claude finished this turn and is waiting for your input.}"
FOCUS_SCRIPT_PATH="${CLAUDE_MUNG_FOCUS_SCRIPT:-$SCRIPT_DIR/mung-focus.sh}"

SESSION_TAG="${MUNG_SESSION_TAG_PREFIX}${SESSION_ID}"
UPDATE_DEDUPE_KEY="${MUNG_SOURCE}:update:${SESSION_ID}"
ACTION_DEDUPE_KEY="${MUNG_SOURCE}:action:${SESSION_ID}"

MUNG_COMMAND="$(resolve_mung_command || true)"
if [[ -z "$MUNG_COMMAND" ]]; then
  debug "mung command unavailable; skipping event=$HOOK_EVENT_NAME"
  exit 0
fi

case "$HOOK_EVENT_NAME" in
  SessionStart|SessionEnd)
    clear_session_alerts "$MUNG_COMMAND"
    ;;

  UserPromptSubmit)
    clear_session_action_alerts "$MUNG_COMMAND"
    ;;

  Notification)
    NOTIFICATION_TYPE="$(normalize_text "$(json_get notification_type)")"

    if [[ "$NOTIFICATION_TYPE" == "permission_prompt" || "$NOTIFICATION_TYPE" == "elicitation_dialog" ]]; then
      build_focus_decision "$FOCUS_SCRIPT_PATH"

      local_action_title="$(json_get title)"
      local_action_message="$(json_get message)"

      if [[ -z "$(normalize_text "$local_action_title")" ]]; then
        local_action_title="$DEFAULT_ACTION_TITLE"
      fi

      if [[ -z "$(normalize_text "$local_action_message")" ]]; then
        local_action_message="$DEFAULT_ACTION_MESSAGE"
      fi

      focus_tag=""
      if [[ -n "$FOCUS_TIER" ]]; then
        focus_tag="${MUNG_FOCUS_TIER_TAG_PREFIX}${FOCUS_TIER}"
      fi

      if [[ -n "$focus_tag" ]]; then
        send_mung_notification \
          "$MUNG_COMMAND" \
          "$local_action_title" \
          "$local_action_message" \
          "$ACTION_ICON" \
          "$MUNG_KIND_ACTION" \
          "$ACTION_DEDUPE_KEY" \
          "$FOCUS_ON_CLICK_COMMAND" \
          "$SESSION_TAG" "$MUNG_ACTION_TAG" "$focus_tag"
      else
        send_mung_notification \
          "$MUNG_COMMAND" \
          "$local_action_title" \
          "$local_action_message" \
          "$ACTION_ICON" \
          "$MUNG_KIND_ACTION" \
          "$ACTION_DEDUPE_KEY" \
          "$FOCUS_ON_CLICK_COMMAND" \
          "$SESSION_TAG" "$MUNG_ACTION_TAG"
      fi
    fi
    ;;

  Stop)
    clear_session_action_alerts "$MUNG_COMMAND"

    TRANSCRIPT_PATH="$(json_get transcript_path)"
    UPDATE_MESSAGE="$(extract_last_assistant_text "$TRANSCRIPT_PATH" "$DEFAULT_UPDATE_MESSAGE")"
    UPDATE_MESSAGE="$(truncate_text "$(normalize_text "$UPDATE_MESSAGE")" 220)"

    build_focus_decision "$FOCUS_SCRIPT_PATH"

    focus_tag=""
    if [[ -n "$FOCUS_TIER" ]]; then
      focus_tag="${MUNG_FOCUS_TIER_TAG_PREFIX}${FOCUS_TIER}"
    fi

    if [[ -n "$focus_tag" ]]; then
      send_mung_notification \
        "$MUNG_COMMAND" \
        "$DEFAULT_UPDATE_TITLE" \
        "$UPDATE_MESSAGE" \
        "$UPDATE_ICON" \
        "$MUNG_KIND_UPDATE" \
        "$UPDATE_DEDUPE_KEY" \
        "$FOCUS_ON_CLICK_COMMAND" \
        "$SESSION_TAG" "$focus_tag"
    else
      send_mung_notification \
        "$MUNG_COMMAND" \
        "$DEFAULT_UPDATE_TITLE" \
        "$UPDATE_MESSAGE" \
        "$UPDATE_ICON" \
        "$MUNG_KIND_UPDATE" \
        "$UPDATE_DEDUPE_KEY" \
        "$FOCUS_ON_CLICK_COMMAND" \
        "$SESSION_TAG"
    fi
    ;;

  *)
    ;;
esac

exit 0
