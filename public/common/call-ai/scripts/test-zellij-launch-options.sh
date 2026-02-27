#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_ASK_AI_ZELLIJ="$SKILL_DIR/ask-ai-zellij.sh"
SOURCE_COMMON="$SCRIPT_DIR/common.sh"

if [[ ! -f "$SOURCE_ASK_AI_ZELLIJ" ]]; then
  echo "Error: ask-ai-zellij.sh not found: $SOURCE_ASK_AI_ZELLIJ" >&2
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

  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$context (missing: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"

  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$context (unexpected: $needle)"
  fi
}

setup_harness() {
  local dir="$1"

  mkdir -p "$dir/scripts"
  cp "$SOURCE_ASK_AI_ZELLIJ" "$dir/ask-ai-zellij.sh"
  cp "$SOURCE_COMMON" "$dir/scripts/common.sh"
  chmod +x "$dir/ask-ai-zellij.sh"

  cat > "$dir/ask-ai.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "fallback-ask-ai"
EOF
  chmod +x "$dir/ask-ai.sh"

  cat > "$dir/scripts/zellij-ai-pane.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

AI="$1"
MODEL="$2"
PROMPT_FILE="$3"
RAW_FILE="$4"
ERR_FILE="$5"
DONE_SENTINEL="$6"
PANE_HOLD="$7"
PANE_HOLD_ERROR="$8"
PID_FILE="${9:-}"

[[ -n "$PID_FILE" ]] && echo $$ > "$PID_FILE"

echo "pane-stub:$AI:$MODEL" > "$RAW_FILE"
: > "$ERR_FILE"
echo "0" > "$DONE_SENTINEL"
EOF
  chmod +x "$dir/scripts/zellij-ai-pane.sh"

  cat > "$dir/zellij" <<EOF
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "\$@" > "$dir/zellij-argv.txt"

while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "--" ]]; then
    shift
    break
  fi
  shift
done

if [[ \$# -eq 0 ]]; then
  exit 1
fi

"\$@"
EOF
  chmod +x "$dir/zellij"
}

run_case() {
  local case_name="$1"
  local expect_stacked="$2"
  local expect_direction="$3"
  local expect_name="$4"
  shift 4

  local harness
  harness=$(mktemp -d "${TMP_ROOT}/zellij.XXXXXX")
  setup_harness "$harness"

  local output
  output=$(env -i PATH="$harness:$PATH" HOME="$HOME" ZELLIJ=1 "$@" "$harness/ask-ai-zellij.sh" codex model-x "prompt")

  local argv_text
  argv_text="$(cat "$harness/zellij-argv.txt")"

  if [[ "$expect_stacked" == "yes" ]]; then
    assert_contains "$argv_text" "--stacked" "$case_name"
  else
    assert_not_contains "$argv_text" "--stacked" "$case_name"
  fi

  if [[ -n "$expect_direction" ]]; then
    assert_contains "$argv_text" "--direction" "$case_name"
    assert_contains "$argv_text" "$expect_direction" "$case_name"
  else
    assert_not_contains "$argv_text" "--direction" "$case_name"
  fi

  if [[ -n "$expect_name" ]]; then
    assert_contains "$argv_text" "--name" "$case_name"
    assert_contains "$argv_text" "$expect_name" "$case_name"
  else
    assert_not_contains "$argv_text" "--name" "$case_name"
  fi

  assert_contains "$output" "pane-stub:codex:model-x" "$case_name"
  echo "PASS: $case_name"
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/call-ai-zellij-option-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

run_case "default launch is stacked" "yes" "" ""
run_case "split-right launch when stacked disabled" "no" "right" "" "ZELLIJ_AI_STACKED=0" "ZELLIJ_AI_DIRECTION=right"
run_case "pane name option is forwarded" "yes" "" "AI Stack" "ZELLIJ_AI_PANE_NAME=AI Stack"

echo "All ask-ai-zellij launch option tests passed."
