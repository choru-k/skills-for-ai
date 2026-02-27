#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_RUN_PARALLEL="$SCRIPT_DIR/run-parallel.sh"
SOURCE_COMMON="$SCRIPT_DIR/common.sh"

if [[ ! -f "$SOURCE_RUN_PARALLEL" ]]; then
  echo "Error: run-parallel.sh not found: $SOURCE_RUN_PARALLEL" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_COMMON" ]]; then
  echo "Error: common.sh not found: $SOURCE_COMMON" >&2
  exit 1
fi

fail() {
  local message="$1"
  echo "FAIL: $message" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"

  if ! grep -Fq "$needle" <<<"$haystack"; then
    fail "$context (missing: $needle)"
  fi
}

setup_harness() {
  local dir="$1"

  mkdir -p "$dir/scripts"
  cp "$SOURCE_RUN_PARALLEL" "$dir/scripts/run-parallel.sh"
  cp "$SOURCE_COMMON" "$dir/scripts/common.sh"
  chmod +x "$dir/scripts/run-parallel.sh"

  cat > "$dir/ask-ai-runner.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ai="$1"
model="$2"

if [[ "$ai" == "fail" ]]; then
  echo "simulated failure for $ai $model" >&2
  exit 1
fi

echo "stub-response:$ai:$model:stacked=${ZELLIJ_AI_STACKED:-}:direction=${ZELLIJ_AI_DIRECTION:-}"
EOF
  chmod +x "$dir/ask-ai-runner.sh"
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/call-ai-run-parallel-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

HARNESS=$(mktemp -d "${TMP_ROOT}/harness.XXXXXX")
setup_harness "$HARNESS"

PROMPT_FILE="$HARNESS/prompt.txt"
echo "test prompt" > "$PROMPT_FILE"

# Case 1: success path uses ask-ai-runner.sh and preserves output blocks.
SUCCESS_STDOUT="$HARNESS/success.out"
SUCCESS_STDERR="$HARNESS/success.err"

if ! ZELLIJ="" "$HARNESS/scripts/run-parallel.sh" "$PROMPT_FILE" codex model-a gemini model-b >"$SUCCESS_STDOUT" 2>"$SUCCESS_STDERR"; then
  fail "run-parallel success case exited non-zero"
fi

SUCCESS_OUTPUT="$(cat "$SUCCESS_STDOUT")"
assert_contains "$SUCCESS_OUTPUT" "=== RESULT: codex model-a ===" "success case"
assert_contains "$SUCCESS_OUTPUT" "stub-response:codex:model-a" "success case"
assert_contains "$SUCCESS_OUTPUT" "=== RESULT: gemini model-b ===" "success case"
assert_contains "$SUCCESS_OUTPUT" "stub-response:gemini:model-b:stacked=:direction=" "success case"

# Case 2: in Zellij, side-stack layout env vars are passed to runner calls.
ZELLIJ_STDOUT="$HARNESS/zellij.out"
ZELLIJ_STDERR="$HARNESS/zellij.err"

if ! ZELLIJ=1 ZELLIJ_AI_LAYOUT_SETTLE_SECS=0 "$HARNESS/scripts/run-parallel.sh" "$PROMPT_FILE" codex model-a gemini model-b claude model-c >"$ZELLIJ_STDOUT" 2>"$ZELLIJ_STDERR"; then
  fail "run-parallel zellij side-stack case exited non-zero"
fi

ZELLIJ_OUTPUT="$(cat "$ZELLIJ_STDOUT")"
assert_contains "$ZELLIJ_OUTPUT" "stub-response:codex:model-a:stacked=0:direction=right" "zellij side-stack case"
assert_contains "$ZELLIJ_OUTPUT" "stub-response:gemini:model-b:stacked=1:direction=" "zellij side-stack case"
assert_contains "$ZELLIJ_OUTPUT" "stub-response:claude:model-c:stacked=1:direction=" "zellij side-stack case"

# Case 3: side-stack can be disabled explicitly.
ZELLIJ_DISABLED_STDOUT="$HARNESS/zellij-disabled.out"
ZELLIJ_DISABLED_STDERR="$HARNESS/zellij-disabled.err"

if ! ZELLIJ=1 ZELLIJ_AI_SIDE_STACK_LAYOUT=0 "$HARNESS/scripts/run-parallel.sh" "$PROMPT_FILE" codex model-a gemini model-b >"$ZELLIJ_DISABLED_STDOUT" 2>"$ZELLIJ_DISABLED_STDERR"; then
  fail "run-parallel zellij disabled-layout case exited non-zero"
fi

ZELLIJ_DISABLED_OUTPUT="$(cat "$ZELLIJ_DISABLED_STDOUT")"
assert_contains "$ZELLIJ_DISABLED_OUTPUT" "stub-response:codex:model-a:stacked=:direction=" "zellij disabled-layout case"
assert_contains "$ZELLIJ_DISABLED_OUTPUT" "stub-response:gemini:model-b:stacked=:direction=" "zellij disabled-layout case"

# Case 4: failure path propagates non-zero and includes stderr block.
FAIL_STDOUT="$HARNESS/fail.out"
FAIL_STDERR="$HARNESS/fail.err"

set +e
ZELLIJ="" "$HARNESS/scripts/run-parallel.sh" "$PROMPT_FILE" fail broken-model >"$FAIL_STDOUT" 2>"$FAIL_STDERR"
STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]]; then
  fail "run-parallel failure case exited zero"
fi

FAIL_OUTPUT="$(cat "$FAIL_STDOUT")"
assert_contains "$FAIL_OUTPUT" "=== RESULT: fail broken-model ===" "failure case"
assert_contains "$FAIL_OUTPUT" "[stderr]" "failure case"
assert_contains "$FAIL_OUTPUT" "simulated failure for fail broken-model" "failure case"

echo "PASS: run-parallel uses ask-ai-runner, handles zellij side-stack env, and propagates failures"
