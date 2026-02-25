#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREPARE_SCRIPT="$SCRIPT_DIR/prepare-front-compaction.sh"
REINJECT_SCRIPT="$SCRIPT_DIR/reinject-after-compact.sh"
FIXTURE_OK="$SCRIPT_DIR/testdata/transcript-6-turns.jsonl"
FIXTURE_SHORT="$SCRIPT_DIR/testdata/transcript-2-turns.jsonl"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

export FRONT_COMPACTION_ROOT="$tmp_root/front-compaction"
mkdir -p "$FRONT_COMPACTION_ROOT"

session_id="test-session-front-compaction"

assert_contains() {
  local needle=$1
  local haystack=$2
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

echo "[1/6] prepare should succeed for 50% with 6 complete turns"
out_prepare=$(
  "$PREPARE_SCRIPT" \
    --session-id "$session_id" \
    --transcript-path "$FIXTURE_OK" \
    50 \
    focus on TODOs
)
assert_contains "Front compaction prepared (50%, hard)." "$out_prepare"
assert_contains "Next step: run /compact" "$out_prepare"

pending_file="$FRONT_COMPACTION_ROOT/state/${session_id}.pending"
if [[ ! -f "$pending_file" ]]; then
  echo "Pending file not created: $pending_file" >&2
  exit 1
fi

pack_path=$(cat "$pending_file")
if [[ ! -f "$pack_path" ]]; then
  echo "Pack file not created: $pack_path" >&2
  exit 1
fi

jq -e '.mode == "hard" and .percent == 50 and .session.totalTurns == 6 and .session.compactedTurns == 3 and .session.keptTurns == 3' "$pack_path" >/dev/null


echo "[2/6] reinject hook should emit SessionStart additionalContext JSON"
hook_input=$(jq -n --arg sid "$session_id" '{hook_event_name:"SessionStart", source:"compact", session_id:$sid}')
out_reinject=$(printf '%s' "$hook_input" | "$REINJECT_SCRIPT")

printf '%s' "$out_reinject" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null
printf '%s' "$out_reinject" | jq -e '.hookSpecificOutput.additionalContext | contains("Front Compaction Replay (hard mode)")' >/dev/null

if [[ -f "$pending_file" ]]; then
  echo "Pending file should be removed after successful reinjection" >&2
  exit 1
fi


echo "[3/6] invalid percent should fail with clear message and clear stale pending"
out_prepare_again=$(
  "$PREPARE_SCRIPT" \
    --session-id "$session_id" \
    --transcript-path "$FIXTURE_OK" \
    30
)
assert_contains "Front compaction prepared (30%, hard)." "$out_prepare_again"
if [[ ! -f "$pending_file" ]]; then
  echo "Pending file not created for stale-pending validation" >&2
  exit 1
fi

invalid_stdout=$(mktemp)
invalid_stderr=$(mktemp)
if "$PREPARE_SCRIPT" --session-id "$session_id" --transcript-path "$FIXTURE_OK" 0 >"$invalid_stdout" 2>"$invalid_stderr"; then
  echo "Expected invalid percent invocation to fail" >&2
  rm -f "$invalid_stdout" "$invalid_stderr"
  exit 1
fi
invalid_err=$(cat "$invalid_stderr")
rm -f "$invalid_stdout" "$invalid_stderr"
assert_contains "front-compaction: Percent must be between 1 and 99." "$invalid_err"

if [[ -f "$pending_file" ]]; then
  echo "Pending file should be cleared after failed prepare attempt" >&2
  exit 1
fi


echo "[4/6] insufficient turns should fail with Unsupported"
short_stdout=$(mktemp)
short_stderr=$(mktemp)
if "$PREPARE_SCRIPT" --session-id "$session_id" --transcript-path "$FIXTURE_SHORT" 50 >"$short_stdout" 2>"$short_stderr"; then
  echo "Expected short transcript invocation to fail" >&2
  rm -f "$short_stdout" "$short_stderr"
  exit 1
fi
short_err=$(cat "$short_stderr")
rm -f "$short_stdout" "$short_stderr"
assert_contains "Unsupported:" "$short_err"


echo "[5/6] compact SessionStart without pending pack should be no-op"
out_noop=$(printf '%s' "$hook_input" | "$REINJECT_SCRIPT")
if [[ -n "$out_noop" ]]; then
  echo "Expected empty output when no pending pack exists" >&2
  echo "$out_noop" >&2
  exit 1
fi

echo "[6/6] logs should contain prepare/reinject events"
log_file="$FRONT_COMPACTION_ROOT/logs/front-compaction.jsonl"
if [[ ! -f "$log_file" ]]; then
  echo "Expected log file to exist: $log_file" >&2
  exit 1
fi
log_dump=$(cat "$log_file")
assert_contains '"event":"prepare"' "$log_dump"
assert_contains '"event":"reinject"' "$log_dump"


echo "front-compaction validation passed"
