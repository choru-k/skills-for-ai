#!/usr/bin/env bash
# Test suite for context-fork.sh
# Run: bash public/claude/cc-context-fork/scripts/test-context-fork.sh
#
# Uses a mock `claude` CLI prepended to PATH. Each test function (test_*)
# is auto-discovered and executed in isolation.

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────
ORIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_SUT="$ORIG_SCRIPT_DIR/context-fork.sh"

# ── Temp dir & cleanup ─────────────────────────────────────────────────
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# ── SUT Isolation ──────────────────────────────────────────────────────
# Copy SUT to temp dir so it writes .responses locally instead of in the source tree
mkdir -p "$TEST_TMPDIR/scripts"
cp "$ORIG_SUT" "$TEST_TMPDIR/scripts/context-fork.sh"
SUT="$TEST_TMPDIR/scripts/context-fork.sh"
# The SUT writes to ../.responses relative to itself
RESPONSES_DIR="$TEST_TMPDIR/.responses"

# ── Mock claude CLI ────────────────────────────────────────────────────
MOCK_BIN="$TEST_TMPDIR/bin"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
# Mock claude — records invocations and produces controlled output.
MOCK_DIR="${MOCK_CLAUDE_DIR:?MOCK_CLAUDE_DIR not set}"
# Save args NUL-delimited to preserve argument boundaries
printf '%s\0' "$@" >> "$MOCK_DIR/args.log"
cat <&0 > "$MOCK_DIR/stdin.log" 2>/dev/null || true
echo -n "${MOCK_CLAUDE_STDOUT:-}" >&1
echo -n "${MOCK_CLAUDE_STDERR:-}" >&2
exit "${MOCK_CLAUDE_EXIT_CODE:-0}"
MOCK
chmod +x "$MOCK_BIN/claude"

# ── Test state ─────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
FAILURES=()

reset_mock() {
  rm -rf "$RESPONSES_DIR"/fork-* 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR/mock"
  rm -f "$TEST_TMPDIR/mock"/{args,stdin}.log
  export MOCK_CLAUDE_DIR="$TEST_TMPDIR/mock"
  export MOCK_CLAUDE_STDOUT=""
  export MOCK_CLAUDE_STDERR=""
  export MOCK_CLAUDE_EXIT_CODE=0
}

# ── Assert helpers ─────────────────────────────────────────────────────
assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [[ "$expected" != "$actual" ]]; then
    echo "  ASSERT_EQ FAILED${msg:+: $msg}" >&2
    echo "    expected: $(printf '%q' "$expected")" >&2
    echo "    actual:   $(printf '%q' "$actual")" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  ASSERT_CONTAINS FAILED${msg:+: $msg}" >&2
    echo "    needle:   $needle" >&2
    echo "    haystack: ${haystack:0:200}" >&2
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ASSERT_NOT_CONTAINS FAILED${msg:+: $msg}" >&2
    echo "    needle:   $needle" >&2
    echo "    haystack: ${haystack:0:200}" >&2
    return 1
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-}"
  if [[ ! -f "$path" ]]; then
    echo "  ASSERT_FILE_EXISTS FAILED${msg:+: $msg}" >&2
    echo "    path: $path" >&2
    return 1
  fi
}

assert_file_not_exists() {
  local pattern="$1" msg="${2:-}"
  local matches
  matches=$(compgen -G "$pattern" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    echo "  ASSERT_FILE_NOT_EXISTS FAILED${msg:+: $msg}" >&2
    echo "    pattern: $pattern" >&2
    echo "    found:   $matches" >&2
    return 1
  fi
}

assert_file_contains() {
  local path="$1" needle="$2" msg="${3:-}"
  if [[ ! -f "$path" ]]; then
    echo "  ASSERT_FILE_CONTAINS FAILED (file missing)${msg:+: $msg}" >&2
    echo "    path: $path" >&2
    return 1
  fi
  if ! grep -qF "$needle" "$path"; then
    echo "  ASSERT_FILE_CONTAINS FAILED${msg:+: $msg}" >&2
    echo "    needle: $needle" >&2
    echo "    file:   $path" >&2
    return 1
  fi
}

# ── Helpers ────────────────────────────────────────────────────────────
make_prompt_file() {
  local f="$TEST_TMPDIR/prompt.txt"
  echo "test prompt content" > "$f"
  echo "$f"
}

mock_args() {
  tr '\0' '\n' < "$MOCK_CLAUDE_DIR/args.log" 2>/dev/null || true
}

mock_stdin() {
  cat "$MOCK_CLAUDE_DIR/stdin.log" 2>/dev/null || true
}

# Standard PATH with mock claude in front
TEST_PATH="$MOCK_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

create_minimal_env() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  # commands needed by SUT or bash to run
  local tools="bash env sh dirname mkdir date cat rm cp grep sed awk"
  for tool in $tools; do
    local src
    src="$(command -v "$tool" 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
        ln -s "$src" "$target_dir/$tool" 2>/dev/null || true
    fi
  done
}

# Run the SUT, capturing stdout+stderr and exit code.
# Usage: run_sut [args...]
run_sut() {
  local exit_code=0
  SUT_OUTPUT="$(PATH="$TEST_PATH" bash "$SUT" "$@" 2>&1)" || exit_code=$?
  SUT_EXIT=$exit_code
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 1: Input Validation
# ═══════════════════════════════════════════════════════════════════════

test_missing_session_id() {
  run_sut
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Usage:" "should print usage"
}

test_missing_model() {
  run_sut "some-session"
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Usage:" "should print usage"
}

test_missing_prompt_file_arg() {
  run_sut "some-session" "haiku"
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Usage:" "should print usage"
}

test_unknown_option() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf" --bogus
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Unknown option" "should say unknown option"
}

test_prompt_file_not_found() {
  run_sut "sess" "haiku" "/tmp/nonexistent-prompt-$$"
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Prompt file not found" "should say prompt file not found"
}

test_claude_cli_not_found() {
  local pf; pf=$(make_prompt_file)
  # Use a minimal PATH that has bash/coreutils but NO claude
  local min_bin="$TEST_TMPDIR/min-bin"
  create_minimal_env "$min_bin"
  
  # We must invoke bash by absolute path if it's not in the PATH lookup for the shell execution itself
  # But here we set PATH for the command.
  # "bash" needs to be in min_bin for the subshell to work if we just call "bash".
  
  SUT_OUTPUT="$(PATH="$min_bin" bash "$SUT" "sess" "haiku" "$pf" 2>&1)" || SUT_EXIT=$?
  SUT_EXIT=${SUT_EXIT:-0}
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "claude CLI not found" "should say CLI not found"
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 2: Argument Parsing
# ═══════════════════════════════════════════════════════════════════════

test_default_tools() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_args)" "--allowedTools" "default tools flag"
  assert_contains "$(mock_args)" "Read,Grep,Glob" "default tools value"
}

test_custom_tools() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf" --tools "Read,Bash,Write"
  assert_contains "$(mock_args)" "--allowedTools" "custom tools flag"
  assert_contains "$(mock_args)" "Read,Bash,Write" "custom tools value"
}

test_tools_without_value() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf" --tools
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "--tools requires a value" "should say requires value"
}

test_passes_system_prompt() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_args)" "--append-system-prompt" "passes --append-system-prompt flag"
  assert_contains "$(mock_args)" "You are a cost-efficient delegate" "passes system prompt value"
}

test_uses_fork_session_flag() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_args)" "--fork-session" "passes --fork-session"
}

test_passes_print_flag() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_args)" "-p" "passes -p flag"
}

test_passes_output_format_json() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_args)" "--output-format" "passes --output-format"
  assert_contains "$(mock_args)" "json" "output format is json"
}

test_opus_model() {
  local pf; pf=$(make_prompt_file)
  run_sut "sess" "opus" "$pf"
  assert_contains "$(mock_args)" "--model" "opus model flag"
  assert_contains "$(mock_args)" "opus" "opus model value"
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 3: Session ID Fallback
# ═══════════════════════════════════════════════════════════════════════

test_resume_normal_session_id() {
  local pf; pf=$(make_prompt_file)
  run_sut "abc-123" "haiku" "$pf"
  assert_contains "$(mock_args)" "--resume" "normal session → --resume flag"
  assert_contains "$(mock_args)" "abc-123" "normal session → session id"
}

test_resume_literal_unexpanded_variable() {
  local pf; pf=$(make_prompt_file)
  # Pass the literal string '${CLAUDE_SESSION_ID}' (single-quoted prevents expansion)
  run_sut '${CLAUDE_SESSION_ID}' "haiku" "$pf"
  assert_contains "$(mock_args)" "--continue" "unexpanded var → --continue"
  assert_not_contains "$(mock_args)" "--resume" "should not have --resume"
}

test_empty_session_id_rejected() {
  local pf; pf=$(make_prompt_file)
  # Empty string "" triggers ${1:?...} before the -z check
  run_sut "" "haiku" "$pf"
  assert_eq 1 "$SUT_EXIT" "should exit 1"
  assert_contains "$SUT_OUTPUT" "Usage:" "should print usage"
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 4: Happy Path
# ═══════════════════════════════════════════════════════════════════════

test_happy_path_json_with_jq() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_STDOUT='{"result":"Hello from fork","model":"haiku"}'
  run_sut "sess" "haiku" "$pf"
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  assert_contains "$SUT_OUTPUT" "FILE:" "should print FILE:"
  assert_contains "$SUT_OUTPUT" "PROMPT:" "should print PROMPT:"
  assert_contains "$SUT_OUTPUT" "Hello from fork" "should contain extracted result"
  # Verify jq actually extracted — output should NOT contain the JSON wrapper
  assert_not_contains "$SUT_OUTPUT" '"model":"haiku"' "should not contain raw JSON fields"
}

test_happy_path_without_jq() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_STDOUT='{"result":"Hello from fork","model":"haiku"}'

  # Build a minimal bin dir: mock claude + essential coreutils, but NO jq.
  local nojq_bin="$TEST_TMPDIR/nojq-bin"
  create_minimal_env "$nojq_bin"
  cp "$MOCK_BIN/claude" "$nojq_bin/claude"
  
  SUT_OUTPUT="$(PATH="$nojq_bin" bash "$SUT" "sess" "haiku" "$pf" 2>&1)" || SUT_EXIT=$?
  SUT_EXIT=${SUT_EXIT:-0}
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  # Without jq, raw JSON is preserved
  assert_contains "$SUT_OUTPUT" '"result"' "should contain raw JSON"
}

test_happy_path_empty_result_field() {
  local pf; pf=$(make_prompt_file)
  # JSON with no .result field → jq outputs empty → falls back to raw
  export MOCK_CLAUDE_STDOUT='{"model":"haiku","usage":{}}'
  run_sut "sess" "haiku" "$pf"
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  assert_contains "$SUT_OUTPUT" '"model"' "should contain raw JSON as fallback"
}

test_pipes_prompt_to_stdin() {
  local pf; pf=$(make_prompt_file)
  echo "unique-prompt-content-$$" > "$pf"
  run_sut "sess" "haiku" "$pf"
  assert_contains "$(mock_stdin)" "unique-prompt-content-$$" "prompt piped to stdin"
}

test_malformed_json_with_jq() {
  local pf; pf=$(make_prompt_file)
  # Malformed JSON — jq will fail, SUT should fall back to raw output
  export MOCK_CLAUDE_STDOUT='not valid json {{'
  run_sut "sess" "haiku" "$pf"
  # SUT should still succeed (jq failure is non-fatal due to fallback)
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  assert_contains "$SUT_OUTPUT" "not valid json" "should preserve raw output"
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 5: Error Handling
# ═══════════════════════════════════════════════════════════════════════

test_claude_nonzero_with_output() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_EXIT_CODE=1
  export MOCK_CLAUDE_STDOUT='{"error":"rate limited"}'
  run_sut "sess" "haiku" "$pf"
  assert_eq 1 "$SUT_EXIT" "should propagate exit code"
  assert_contains "$SUT_OUTPUT" "FILE:" "should still print FILE:"
  assert_contains "$SUT_OUTPUT" "rate limited" "should preserve output"
  assert_contains "$SUT_OUTPUT" "exited with code 1" "should report error"
}

test_claude_nonzero_no_output() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_EXIT_CODE=2
  export MOCK_CLAUDE_STDOUT=""
  run_sut "sess" "haiku" "$pf"
  assert_eq 2 "$SUT_EXIT" "should propagate exit code"
  assert_contains "$SUT_OUTPUT" "Fork failed" "should say fork failed"
}

# ═══════════════════════════════════════════════════════════════════════
# GROUP 6: Cleanup
# ═══════════════════════════════════════════════════════════════════════

test_raw_file_cleaned_up() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_STDOUT='{"result":"ok"}'
  run_sut "sess" "haiku" "$pf"
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  assert_file_not_exists "$RESPONSES_DIR/fork-*.raw" "raw file should be removed"
}

test_empty_err_file_cleaned_up() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_STDOUT='{"result":"ok"}'
  export MOCK_CLAUDE_STDERR=""
  run_sut "sess" "haiku" "$pf"
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  assert_file_not_exists "$RESPONSES_DIR/fork-*.err" "empty err file should be removed"
}

test_nonempty_err_file_preserved() {
  local pf; pf=$(make_prompt_file)
  export MOCK_CLAUDE_STDOUT='{"result":"ok"}'
  export MOCK_CLAUDE_STDERR="warning: something happened"
  run_sut "sess" "haiku" "$pf"
  assert_eq 0 "$SUT_EXIT" "should exit 0"
  # Find the .err file
  local err_files
  err_files=$(compgen -G "$RESPONSES_DIR/fork-*.err" 2>/dev/null || true)
  if [[ -z "$err_files" ]]; then
    echo "  ASSERT FAILED: expected .err file to be preserved" >&2
    return 1
  fi
  assert_file_contains "$err_files" "warning: something happened" ".err content"
}

# ═══════════════════════════════════════════════════════════════════════
# Test Runner
# ═══════════════════════════════════════════════════════════════════════

run_all_tests() {
  local tests
  tests=$(declare -F | awk '/test_/{print $3}')

  local total=0
  for t in $tests; do
    ((total++)) || true
  done

  echo "Running $total tests..."
  echo ""

  local current_group=""
  for t in $tests; do
    # Print group header based on function prefix
    local group
    case "$t" in
      test_missing_*|test_unknown_*|test_prompt_*|test_claude_cli_*) group="Input Validation" ;;
      test_default_*|test_custom_*|test_tools_*|test_passes_*|test_uses_*|test_opus_*) group="Argument Parsing" ;;
      test_resume_*|test_empty_session_*) group="Session ID Fallback" ;;
      test_happy_*|test_pipes_*|test_malformed_*) group="Happy Path" ;;
      test_claude_nonzero_*) group="Error Handling" ;;
      test_raw_*|test_empty_err_*|test_nonempty_*) group="Cleanup" ;;
      *) group="Other" ;;
    esac
    if [[ "$group" != "$current_group" ]]; then
      [[ -n "$current_group" ]] && echo ""
      echo "── $group ──"
      current_group="$group"
    fi

    # Reset state
    reset_mock
    SUT_OUTPUT=""
    SUT_EXIT=0

    # Run test
    local result
    if "$t" 2>&1; then
      ((PASS_COUNT++)) || true
      printf "  ✓ %s\n" "$t"
    else
      ((FAIL_COUNT++)) || true
      printf "  ✗ %s\n" "$t"
      FAILURES+=("$t")
    fi
  done

  echo ""
  echo "════════════════════════════════════════════"
  echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (out of $total)"
  echo "════════════════════════════════════════════"

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi
}

run_all_tests