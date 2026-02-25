#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/context-pack.sh
source "$SCRIPT_DIR/lib/context-pack.sh"

fc_require_cmds jq python3
fc_ensure_dirs

session_id="${CLAUDE_SESSION_ID:-}"
project_cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
transcript_path=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --session-id)
      session_id="${2:-}"
      shift 2
      ;;
    --cwd)
      project_cwd="${2:-}"
      shift 2
      ;;
    --transcript-path)
      transcript_path="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$session_id" ]]; then
  fc_log_event "prepare" "error" "" "missing session id" "" ""
  echo "Unsupported: missing session id. Re-run from Claude with \${CLAUDE_SESSION_ID} available." >&2
  exit 2
fi

pending_file=$(fc_pending_path "$session_id")
if [[ -f "$pending_file" ]]; then
  rm -f "$pending_file"
  fc_log_event "prepare" "pending-cleared" "$session_id" "cleared stale pending pack marker before new prepare attempt" "" ""
fi

readarray -t parsed < <(fc_parse_percent_and_focus "$@")
percent="${parsed[0]:-30}"
focus="${parsed[1]:-}"
if ! fc_validate_percent "$percent"; then
  fc_log_event "prepare" "error" "$session_id" "invalid percent input" "$percent" ""
  exit 2
fi

fc_log_event "prepare" "start" "$session_id" "preparing context pack" "$percent" ""

if [[ -z "$transcript_path" ]]; then
  transcript_path=$(fc_find_transcript_path "$session_id" "$project_cwd")
fi

if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
  fc_log_event "prepare" "error" "$session_id" "transcript not found" "$percent" ""
  echo "Unsupported: transcript not found for session $session_id." >&2
  exit 2
fi

tmp_json=$(mktemp)
tmp_err=$(mktemp)
trap 'rm -f "$tmp_json" "$tmp_err"' EXIT

if python3 "$SCRIPT_DIR/lib/build_context_pack.py" \
  --transcript-path "$transcript_path" \
  --session-id "$session_id" \
  --percent "$percent" \
  --focus "$focus" \
  --max-head-chars 4000 \
  --max-tail-chars 16000 \
  --max-replay-chars 19000 > "$tmp_json" 2> "$tmp_err"; then
  :
else
  status=$?
  err_message=$(tr '\n' ' ' < "$tmp_err" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
  fc_log_event "prepare" "error" "$session_id" "$err_message" "$percent" ""
  cat "$tmp_err" >&2
  exit "$status"
fi

ts=$(date -u +"%Y%m%dT%H%M%SZ")
pack_path=$(fc_pack_path "$session_id" "$ts")
cp "$tmp_json" "$pack_path"

ln -sfn "$pack_path" "$(fc_latest_link "$session_id")"
printf '%s\n' "$pack_path" > "$(fc_pending_path "$session_id")"

fc_cleanup_old_packs "$session_id"

compacted=$(jq -r '.session.compactedTurns' "$pack_path")
total=$(jq -r '.session.totalTurns' "$pack_path")
kept=$(jq -r '.session.keptTurns' "$pack_path")

fc_log_event "prepare" "success" "$session_id" "prepared compacted=${compacted} total=${total} kept=${kept}" "$percent" "$pack_path"

fc_emit_prepared "$percent" "$compacted" "$total" "$kept" "$pack_path"
