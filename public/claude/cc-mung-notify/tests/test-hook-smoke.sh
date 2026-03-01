#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/mung-notify.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"
LOG_FILE="$TMP_DIR/mung-log.jsonl"
TRANSCRIPT_FILE="$TMP_DIR/transcript.jsonl"

cat > "$TMP_DIR/bin/mung" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "version" ]]; then
  echo "mung 0.0.0"
  exit 0
fi

python3 - "$FAKE_MUNG_LOG" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
args = sys.argv[2:]

with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(args) + "\n")
PY
EOS

chmod +x "$TMP_DIR/bin/mung"

cat > "$TRANSCRIPT_FILE" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Smoke test update message."}]}}
EOF

export PATH="$TMP_DIR/bin:$PATH"
export FAKE_MUNG_LOG="$LOG_FILE"
export CLAUDE_MUNG_SOURCE="claude-agent-test"
export CLAUDE_MUNG_FOCUS_SCRIPT="$SCRIPT_DIR/../hooks/mung-focus.sh"

printf '%s' '{"hook_event_name":"SessionStart","session_id":"sess-123"}' | "$HOOK_SCRIPT"
printf '%s' '{"hook_event_name":"Notification","session_id":"sess-123","notification_type":"permission_prompt","title":"Permission needed","message":"Please approve"}' | "$HOOK_SCRIPT"
printf '%s' "{\"hook_event_name\":\"Stop\",\"session_id\":\"sess-123\",\"transcript_path\":\"$TRANSCRIPT_FILE\"}" | "$HOOK_SCRIPT"

python3 - "$LOG_FILE" <<'PY'
import json
import sys

entries = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8")]

if len(entries) < 4:
    raise SystemExit(f"Expected at least 4 mung calls, got {len(entries)}")


def has_flags(args, expected):
    for i in range(len(args) - 1):
        flag = args[i]
        value = args[i + 1]
        if flag in expected and expected[flag] == value:
            expected = {k: v for k, v in expected.items() if k != flag}
    return not expected

assert entries[0][:1] == ["clear"], entries[0]
assert has_flags(entries[0], {"--source": "claude-agent-test", "--session": "sess-123"}), entries[0]

action_add = next((e for e in entries if e[:1] == ["add"] and "--kind" in e and e[e.index("--kind") + 1] == "action"), None)
if not action_add:
    raise SystemExit("Missing action add command")
assert has_flags(action_add, {
    "--source": "claude-agent-test",
    "--session": "sess-123",
    "--dedupe-key": "claude-agent-test:action:sess-123",
}), action_add

clear_action = next((e for e in entries if e[:1] == ["clear"] and "--kind" in e and e[e.index("--kind") + 1] == "action"), None)
if not clear_action:
    raise SystemExit("Missing action clear command")

update_add = next((e for e in entries if e[:1] == ["add"] and "--kind" in e and e[e.index("--kind") + 1] == "update"), None)
if not update_add:
    raise SystemExit("Missing update add command")
assert has_flags(update_add, {
    "--source": "claude-agent-test",
    "--session": "sess-123",
    "--dedupe-key": "claude-agent-test:update:sess-123",
}), update_add
if "--message" not in update_add:
    raise SystemExit("Update command missing message")
message = update_add[update_add.index("--message") + 1]
if "Smoke test update message." not in message:
    raise SystemExit(f"Unexpected update message: {message}")

print("ok")
PY
