#!/usr/bin/env bash

set -euo pipefail

FRONT_COMPACTION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONT_COMPACTION_ROOT_DEFAULT="$(cd "$FRONT_COMPACTION_LIB_DIR/.." && pwd)"
FRONT_COMPACTION_ROOT="${FRONT_COMPACTION_ROOT:-$FRONT_COMPACTION_ROOT_DEFAULT}"
FRONT_COMPACTION_PACK_DIR="$FRONT_COMPACTION_ROOT/context-pack"
FRONT_COMPACTION_STATE_DIR="$FRONT_COMPACTION_ROOT/state"
FRONT_COMPACTION_LOG_DIR="$FRONT_COMPACTION_ROOT/logs"
FRONT_COMPACTION_LOG_FILE="$FRONT_COMPACTION_LOG_DIR/front-compaction.jsonl"
FRONT_COMPACTION_MAX_KEEP_PER_SESSION="${FRONT_COMPACTION_MAX_KEEP_PER_SESSION:-3}"

fc_require_cmds() {
  local missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Unsupported: required command not found: $cmd" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    exit 2
  fi
}

fc_ensure_dirs() {
  mkdir -p "$FRONT_COMPACTION_PACK_DIR" "$FRONT_COMPACTION_STATE_DIR" "$FRONT_COMPACTION_LOG_DIR"
}

fc_log_event() {
  local event=$1
  local status=$2
  local session_id=${3:-}
  local message=${4:-}
  local percent=${5:-}
  local pack_path=${6:-}

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq -nc \
    --arg timestamp "$ts" \
    --arg event "$event" \
    --arg status "$status" \
    --arg session_id "$session_id" \
    --arg message "$message" \
    --arg percent "$percent" \
    --arg pack_path "$pack_path" \
    '{timestamp:$timestamp,event:$event,status:$status,sessionId:$session_id,message:$message,percent:$percent,packPath:$pack_path}' \
    >> "$FRONT_COMPACTION_LOG_FILE" 2>/dev/null || true
}

fc_pending_path() {
  local session_id=$1
  echo "$FRONT_COMPACTION_STATE_DIR/${session_id}.pending"
}

fc_latest_link() {
  local session_id=$1
  echo "$FRONT_COMPACTION_PACK_DIR/latest-${session_id}.json"
}

fc_pack_path() {
  local session_id=$1
  local ts=$2
  echo "$FRONT_COMPACTION_PACK_DIR/${session_id}-${ts}.json"
}

fc_cleanup_old_packs() {
  local session_id=$1
  local keep=$FRONT_COMPACTION_MAX_KEEP_PER_SESSION

  shopt -s nullglob
  local files=("$FRONT_COMPACTION_PACK_DIR/${session_id}-"*.json)
  shopt -u nullglob

  if [[ "${#files[@]}" -le "$keep" ]]; then
    return
  fi

  local sorted
  sorted=$(ls -1t "${files[@]}")
  local idx=0
  while IFS= read -r file; do
    idx=$((idx + 1))
    if [[ "$idx" -gt "$keep" ]]; then
      rm -f "$file"
    fi
  done <<< "$sorted"
}

fc_default_project_slug() {
  local cwd=$1
  printf '%s' "$cwd" | sed 's#/#-#g'
}

fc_find_transcript_path() {
  local session_id=$1
  local cwd=$2

  local slug
  slug=$(fc_default_project_slug "$cwd")
  local guessed="$HOME/.claude/projects/${slug}/${session_id}.jsonl"
  if [[ -f "$guessed" ]]; then
    echo "$guessed"
    return
  fi

  local found
  found=$(find "$HOME/.claude/projects" -maxdepth 3 -type f -name "${session_id}.jsonl" 2>/dev/null | head -n 1 || true)
  if [[ -n "$found" ]]; then
    echo "$found"
    return
  fi

  echo ""
}

fc_parse_percent_and_focus() {
  local default_percent=30
  local percent=""
  local focus=""

  if [[ "$#" -gt 0 && "${1:-}" =~ ^[0-9]+$ ]]; then
    percent=$1
    shift
  else
    percent=$default_percent
  fi

  if [[ "$#" -gt 0 ]]; then
    focus="$*"
  fi

  echo "$percent"$'\n'"$focus"
}

fc_validate_percent() {
  local percent=$1
  if ! [[ "$percent" =~ ^[0-9]+$ ]]; then
    echo "front-compaction: Percent must be between 1 and 99." >&2
    return 1
  fi

  if [[ "$percent" -lt 1 || "$percent" -gt 99 ]]; then
    echo "front-compaction: Percent must be between 1 and 99." >&2
    return 1
  fi

  return 0
}

fc_emit_prepared() {
  local percent=$1
  local compacted=$2
  local total=$3
  local kept=$4
  local pack_path=$5

  cat <<EOF
Front compaction prepared (${percent}%, hard).
- Compacted oldest turns: ${compacted}/${total}
- Kept tail turns: ${kept}
- Context pack: ${pack_path}
Next step: run /compact
EOF
}
