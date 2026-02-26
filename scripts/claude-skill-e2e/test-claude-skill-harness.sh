#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="$SCRIPT_DIR/claude-skill-harness.py"

if [[ ! -f "$HARNESS" ]]; then
  echo "Error: harness not found: $HARNESS" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required" >&2
  exit 1
fi

fail() {
  local message="$1"
  echo "FAIL: $message" >&2
  exit 1
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/claude-skill-harness-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

STUB_CLAUDE="$TMP_ROOT/claude"
cat > "$STUB_CLAUDE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

session_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      session_id="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$session_id" ]]; then
  session_id="${CLAUDE_STUB_SESSION_ID:-stub-session-1}"
fi

prompt=$(cat)

if [[ "${CLAUDE_STUB_MODE:-ok}" == "fail" ]]; then
  echo "stub failure" >&2
  exit 2
fi

python3 - "$prompt" "$session_id" <<'PY'
import json
import sys

prompt = sys.argv[1]
session_id = sys.argv[2]
text = f"stub:{prompt}"

print(json.dumps({
    "type": "system",
    "subtype": "init",
    "session_id": session_id,
    "skills": ["cc-front-compaction", "call-ai"],
    "slash_commands": ["cc-front-compaction", "call-ai"],
}))
print(json.dumps({
    "type": "assistant",
    "message": {
        "role": "assistant",
        "content": [{"type": "text", "text": text}],
    },
    "session_id": session_id,
}))
print(json.dumps({
    "type": "result",
    "subtype": "success",
    "is_error": False,
    "session_id": session_id,
    "result": text,
}))
PY
EOF
chmod +x "$STUB_CLAUDE"

RUN_OUTPUT_DIR="$TMP_ROOT/run-out"
RUN_JSON=$(python3 "$HARNESS" run \
  --prompt "hello-from-run" \
  --cwd "$TMP_ROOT" \
  --model "sonnet" \
  --claude-bin "$STUB_CLAUDE" \
  --output-dir "$RUN_OUTPUT_DIR" \
  --run-name "stub-run")

RUN_SUMMARY="$TMP_ROOT/run-summary.json"
printf '%s\n' "$RUN_JSON" > "$RUN_SUMMARY"

python3 - "$RUN_SUMMARY" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
files = summary["files"]
assistant_text = Path(files["assistant"]).read_text()

if summary["exit_code"] != 0:
    raise SystemExit("expected exit_code 0")
if summary.get("session_id") != "stub-session-1":
    raise SystemExit("expected session_id stub-session-1")
if "cc-front-compaction" not in summary.get("skills", []):
    raise SystemExit("expected cc-front-compaction in skills metadata")
if "stub:hello-from-run" not in assistant_text:
    raise SystemExit("assistant artifact missing expected text")
for key in ("run_dir", "prompt", "stdout", "stderr", "assistant", "summary"):
    if not Path(files[key]).exists():
        raise SystemExit(f"missing artifact file: {key}")
PY

echo "PASS: harness run mode (stub claude)"

CASE_PASS_FILE="$TMP_ROOT/case-pass.json"
cat > "$CASE_PASS_FILE" <<'EOF'
{
  "name": "stub-case-pass",
  "model": "sonnet",
  "cwd": ".",
  "prompt": "hello-from-case",
  "assertions": {
    "exit_code": 0,
    "assistant_contains": ["stub:hello-from-case"],
    "stderr_not_contains": ["stub failure"],
    "assistant_min_chars": 5
  }
}
EOF

CASE_OUTPUT_DIR="$TMP_ROOT/case-out"
python3 "$HARNESS" case \
  --case-file "$CASE_PASS_FILE" \
  --claude-bin "$STUB_CLAUDE" \
  --output-dir "$CASE_OUTPUT_DIR" >/dev/null

echo "PASS: harness case mode pass assertions"

CASE_FAIL_FILE="$TMP_ROOT/case-fail.json"
cat > "$CASE_FAIL_FILE" <<'EOF'
{
  "name": "stub-case-fail",
  "model": "sonnet",
  "cwd": ".",
  "prompt": "hello-from-case-fail",
  "assertions": {
    "exit_code": 0,
    "assistant_contains": ["THIS_TEXT_SHOULD_NOT_APPEAR"]
  }
}
EOF

set +e
python3 "$HARNESS" case \
  --case-file "$CASE_FAIL_FILE" \
  --claude-bin "$STUB_CLAUDE" \
  --output-dir "$CASE_OUTPUT_DIR" >/dev/null
FAIL_STATUS=$?
set -e

if [[ "$FAIL_STATUS" -eq 0 ]]; then
  fail "harness case expected failure but exited 0"
fi

echo "PASS: harness case mode failure assertions"

CASE_MULTI_FILE="$TMP_ROOT/case-multi.json"
cat > "$CASE_MULTI_FILE" <<'EOF'
{
  "name": "stub-case-multi",
  "model": "sonnet",
  "cwd": ".",
  "session_assertions": {
    "session_id_present": true,
    "skills_contains": ["cc-front-compaction"],
    "slash_commands_contains": ["cc-front-compaction"]
  },
  "turns": [
    {
      "prompt": "turn-1",
      "assertions": {
        "assistant_contains": ["stub:turn-1"]
      }
    },
    {
      "prompt": "turn-2",
      "assertions": {
        "assistant_contains": ["stub:turn-2"]
      }
    },
    {
      "prompt": "/cc-front-compaction 30",
      "assertions": {
        "assistant_contains": ["stub:/cc-front-compaction 30"]
      }
    }
  ],
  "assertions": {
    "assistant_contains": ["stub:/cc-front-compaction 30"]
  }
}
EOF

CASE_MULTI_OUTPUT=$(python3 "$HARNESS" case \
  --case-file "$CASE_MULTI_FILE" \
  --claude-bin "$STUB_CLAUDE" \
  --output-dir "$CASE_OUTPUT_DIR")

CASE_MULTI_ARTIFACTS=$(printf '%s\n' "$CASE_MULTI_OUTPUT" | sed -n 's/^  artifacts: //p')
if [[ -z "$CASE_MULTI_ARTIFACTS" ]]; then
  fail "multi-turn case did not print artifact path"
fi

python3 - "$CASE_MULTI_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
if not run_dir.exists():
    raise SystemExit("multi-turn artifact dir missing")

for name in ("turn-01", "turn-02", "turn-03"):
    if not (run_dir / name).is_dir():
        raise SystemExit(f"missing turn directory: {name}")

summary = json.loads((run_dir / "result.json").read_text())
if summary.get("turn_count") != 3:
    raise SystemExit("expected turn_count 3")
if summary.get("session_id") != "stub-session-1":
    raise SystemExit("expected shared session_id across turns")
if summary.get("errors"):
    raise SystemExit("expected no summary errors")
PY

echo "PASS: harness multi-turn case mode"

echo "All claude-skill-harness tests passed."
