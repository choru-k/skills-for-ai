#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$PLUGIN_DIR/hooks/mung-notify.sh"

if [[ ! -x "$HOOK_SCRIPT" ]]; then
  echo "ERROR: hook script is missing or not executable: $HOOK_SCRIPT" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found in PATH" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"
MUNG_LOG_FILE="$TMP_DIR/mung-commands.jsonl"
CLAUDE_OUTPUT_FILE="$TMP_DIR/claude-output.txt"

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

SESSION_ID="${CLAUDE_MUNG_E2E_SESSION_ID:-$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)}"

E2E_SOURCE="${CLAUDE_MUNG_SOURCE:-claude-mung-e2e-$(date +%s)}"
REPLY_TOKEN="claude-mung-e2e-ok-$(date +%s)"

export PATH="$TMP_DIR/bin:$PATH"
export FAKE_MUNG_LOG="$MUNG_LOG_FILE"
export CLAUDE_MUNG_SOURCE="$E2E_SOURCE"
export CLAUDE_MUNG_DEBUG="${CLAUDE_MUNG_DEBUG:-1}"

PROMPT="Reply with exactly this token and nothing else: $REPLY_TOKEN"

set +e
CLAUDE_OUTPUT="$({
  claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --permission-mode bypassPermissions \
    --session-id "$SESSION_ID" \
    "$PROMPT"
} 2>&1)"
CLAUDE_EXIT_CODE=$?
set -e

printf '%s\n' "$CLAUDE_OUTPUT" > "$CLAUDE_OUTPUT_FILE"

if [[ "$CLAUDE_EXIT_CODE" -ne 0 ]]; then
  if grep -qiE "not logged in|organization does not have access|please login|auth" "$CLAUDE_OUTPUT_FILE"; then
    echo "ERROR: Claude auth/access is not ready for live E2E." >&2
    echo "Run /login in Claude Code first, then re-run this test." >&2
    echo "--- claude output ---" >&2
    cat "$CLAUDE_OUTPUT_FILE" >&2
    exit 2
  fi

  echo "ERROR: claude live run failed (exit=$CLAUDE_EXIT_CODE)." >&2
  echo "--- claude output ---" >&2
  cat "$CLAUDE_OUTPUT_FILE" >&2
  exit "$CLAUDE_EXIT_CODE"
fi

if [[ ! -f "$MUNG_LOG_FILE" ]]; then
  echo "ERROR: expected fake mung log file was not created" >&2
  echo "--- claude output ---" >&2
  cat "$CLAUDE_OUTPUT_FILE" >&2
  exit 1
fi

python3 - "$MUNG_LOG_FILE" "$E2E_SOURCE" "$SESSION_ID" <<'PY'
import json
import sys

log_path = sys.argv[1]
source = sys.argv[2]
session = sys.argv[3]

entries: list[list[str]] = []
with open(log_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        entries.append(json.loads(line))

if not entries:
    raise SystemExit("No mung commands captured")


def get_flag(args: list[str], flag: str):
    for i, token in enumerate(args[:-1]):
        if token == flag:
            return args[i + 1]
    return None

scoped = [
    args for args in entries
    if get_flag(args, "--source") == source and get_flag(args, "--session") == session
]

if not scoped:
    raise SystemExit("No scoped mung commands found for expected source/session")

has_session_clear = any(args and args[0] == "clear" for args in scoped)
if not has_session_clear:
    raise SystemExit("Expected at least one session-scoped clear command")

has_action_clear = any(
    args and args[0] == "clear" and get_flag(args, "--kind") == "action"
    for args in scoped
)
if not has_action_clear:
    raise SystemExit("Expected action-lane clear (--kind action)")

update_add = next(
    (
        args
        for args in scoped
        if args
        and args[0] == "add"
        and get_flag(args, "--kind") == "update"
        and get_flag(args, "--dedupe-key") == f"{source}:update:{session}"
    ),
    None,
)
if update_add is None:
    raise SystemExit("Expected update add with metadata dedupe lane")

message = get_flag(update_add, "--message")
if not isinstance(message, str) or not message.strip():
    raise SystemExit("Update add command missing non-empty --message")

print("ok")
PY

if ! grep -Fq "$REPLY_TOKEN" "$CLAUDE_OUTPUT_FILE"; then
  echo "WARN: Claude response did not exactly echo token (run still succeeded)." >&2
  echo "Token: $REPLY_TOKEN" >&2
fi

echo "ok"
echo "source=$E2E_SOURCE"
echo "session=$SESSION_ID"
