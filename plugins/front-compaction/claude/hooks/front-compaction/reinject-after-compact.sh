#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/context-pack.sh
source "$SCRIPT_DIR/lib/context-pack.sh"

fc_require_cmds jq shasum
fc_ensure_dirs

input=$(cat)
source_event=$(printf '%s' "$input" | jq -r '.source // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

if [[ "$source_event" != "compact" ]]; then
  exit 0
fi

if [[ -z "$session_id" ]]; then
  fc_log_event "reinject" "error" "" "missing session_id for compact reinjection" "" ""
  echo "Unsupported: missing session_id for compact reinjection." >&2
  exit 0
fi

pending_file=$(fc_pending_path "$session_id")
if [[ ! -f "$pending_file" ]]; then
  fc_log_event "reinject" "noop" "$session_id" "no pending pack for compact start" "" ""
  exit 0
fi

pack_path=$(cat "$pending_file")
if [[ -z "$pack_path" || ! -f "$pack_path" ]]; then
  rm -f "$pending_file"
  fc_log_event "reinject" "error" "$session_id" "pending marker exists but pack file is missing" "" "$pack_path"
  echo "Unsupported: no valid pending front-compaction pack for session $session_id." >&2
  exit 0
fi

schema=$(jq -r '.schemaVersion // empty' "$pack_path")
pack_session_id=$(jq -r '.session.sessionId // empty' "$pack_path")
replay_content=$(jq -r '.replay.content // empty' "$pack_path")
expected_sha=$(jq -r '.integrity.sha256 // empty' "$pack_path")

if [[ "$schema" != "1" ]]; then
  rm -f "$pending_file"
  fc_log_event "reinject" "error" "$session_id" "schema mismatch: $schema" "" "$pack_path"
  echo "Unsupported: context pack schema mismatch ($schema)." >&2
  exit 0
fi

if [[ "$pack_session_id" != "$session_id" ]]; then
  rm -f "$pending_file"
  fc_log_event "reinject" "error" "$session_id" "session mismatch in context pack" "" "$pack_path"
  echo "Unsupported: context pack session mismatch." >&2
  exit 0
fi

if [[ -z "$replay_content" || -z "$expected_sha" ]]; then
  rm -f "$pending_file"
  fc_log_event "reinject" "error" "$session_id" "missing replay payload or sha" "" "$pack_path"
  echo "Unsupported: context pack missing replay payload or integrity hash." >&2
  exit 0
fi

actual_sha=$(printf '%s' "$replay_content" | shasum -a 256 | awk '{print $1}')
if [[ "$actual_sha" != "$expected_sha" ]]; then
  rm -f "$pending_file"
  fc_log_event "reinject" "error" "$session_id" "integrity check failed" "" "$pack_path"
  echo "Unsupported: context pack integrity check failed." >&2
  exit 0
fi

percent=$(jq -r '.percent // empty' "$pack_path")
fc_log_event "reinject" "success" "$session_id" "replay injected on SessionStart(compact)" "$percent" "$pack_path"

jq -n --arg context "$replay_content" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}'

rm -f "$pending_file"
