#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_RUNNER="$SKILL_DIR/ask-ai-runner.sh"

if [[ ! -x "$SOURCE_RUNNER" ]]; then
  echo "Error: ask-ai-runner.sh not found or not executable: $SOURCE_RUNNER" >&2
  exit 1
fi

PASS_COUNT=0

fail() {
  local message="$1"
  echo "FAIL: $message" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local context="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "$context (expected: '$expected', got: '$actual')"
  fi
}

make_stub() {
  local path="$1"
  local marker="$2"

  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "$marker"
EOF
  chmod +x "$path"
}

setup_harness() {
  local dir="$1"

  cp "$SOURCE_RUNNER" "$dir/ask-ai-runner.sh"
  chmod +x "$dir/ask-ai-runner.sh"

  make_stub "$dir/ask-ai.sh" "ask-ai"
  make_stub "$dir/ask-ai-zellij.sh" "ask-ai-zellij"
  make_stub "$dir/ask-ai-tmux.sh" "ask-ai-tmux"
  make_stub "$dir/ask-ai-ghostty.sh" "ask-ai-ghostty"
}

run_router() {
  local dir="$1"
  shift

  env -i PATH="$PATH" HOME="$HOME" "$@" "$dir/ask-ai-runner.sh" codex model "test prompt"
}

run_case() {
  local name="$1"
  local expected="$2"
  shift 2

  local harness
  harness=$(mktemp -d "${TMP_ROOT}/runner.XXXXXX")
  setup_harness "$harness"

  local output
  output=$(run_router "$harness" "$@")

  assert_eq "$output" "$expected" "$name"
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $name"
}

run_case_with_setup() {
  local name="$1"
  local expected="$2"
  local setup_fn="$3"
  shift 3

  local harness
  harness=$(mktemp -d "${TMP_ROOT}/runner.XXXXXX")
  setup_harness "$harness"
  "$setup_fn" "$harness"

  local output
  output=$(run_router "$harness" "$@")

  assert_eq "$output" "$expected" "$name"
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $name"
}

remove_tmux_stub() {
  local harness="$1"
  rm -f "$harness/ask-ai-tmux.sh"
}

remove_ghostty_stub() {
  local harness="$1"
  rm -f "$harness/ask-ai-ghostty.sh"
}

remove_tmux_and_ghostty_stubs() {
  local harness="$1"
  remove_tmux_stub "$harness"
  remove_ghostty_stub "$harness"
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/call-ai-runner-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

run_case "default -> headless" "ask-ai"
run_case "zellij env -> zellij runner" "ask-ai-zellij" "ZELLIJ=1"
run_case "tmux env -> tmux runner" "ask-ai-tmux" "TMUX=/tmp/tmux-test"
run_case "ghostty TERM_PROGRAM -> ghostty runner" "ask-ai-ghostty" "TERM_PROGRAM=ghostty"
run_case "ghostty resources env -> ghostty runner" "ask-ai-ghostty" "GHOSTTY_RESOURCES_DIR=/tmp/ghostty"
run_case "zellij precedence over tmux+ghostty" "ask-ai-zellij" "ZELLIJ=1" "TMUX=/tmp/tmux-test" "TERM_PROGRAM=ghostty"
run_case "tmux precedence over ghostty" "ask-ai-tmux" "TMUX=/tmp/tmux-test" "TERM_PROGRAM=ghostty"
run_case_with_setup "tmux missing -> ghostty fallback" "ask-ai-ghostty" remove_tmux_stub "TMUX=/tmp/tmux-test" "TERM_PROGRAM=ghostty"
run_case_with_setup "ghostty runner missing -> headless fallback" "ask-ai" remove_ghostty_stub "TERM_PROGRAM=ghostty"
run_case_with_setup "tmux+ghostty runners missing -> headless fallback" "ask-ai" remove_tmux_and_ghostty_stubs "TMUX=/tmp/tmux-test" "TERM_PROGRAM=ghostty"

echo "All runner routing tests passed ($PASS_COUNT cases)."
