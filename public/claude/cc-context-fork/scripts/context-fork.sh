#!/usr/bin/env bash
# Fork the current Claude session to a cheaper model with full context.
#
# Usage:
#   context-fork.sh <session-id> <model> <prompt-file> [--tools <tools>]
#
# The prompt is read from <prompt-file> and piped via stdin to avoid CLI arg
# length limits (same pattern as ask-ai.sh).

set -euo pipefail

SESSION_ID="${1:?Usage: context-fork.sh <session-id> <model> <prompt-file> [--tools <tools>]}"
MODEL="${2:?Usage: context-fork.sh <session-id> <model> <prompt-file> [--tools <tools>]}"
PROMPT_FILE="${3:?Usage: context-fork.sh <session-id> <model> <prompt-file> [--tools <tools>]}"
shift 3

# Parse optional flags
TOOLS="Read,Grep,Glob"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools)
      TOOLS="${2:?--tools requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI not found" >&2
  exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

# Fallback: if session ID substitution failed, use --continue
RESUME_FLAGS=()
if [[ "$SESSION_ID" == '${CLAUDE_SESSION_ID}' || -z "$SESSION_ID" ]]; then
  RESUME_FLAGS=(--continue)
else
  RESUME_FLAGS=(--resume "$SESSION_ID")
fi

# Setup output paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESPONSES_DIR="$(dirname "$SCRIPT_DIR")/.responses"
mkdir -p "$RESPONSES_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUT_FILE="$RESPONSES_DIR/fork-${MODEL}-${TIMESTAMP}-$$.txt"
ERR_FILE="$OUT_FILE.err"

# System prompt: tell the fork it's a delegate
DELEGATE_PROMPT="You are a cost-efficient delegate with full conversation context. Answer the task concisely. Do not make file modifications unless explicitly instructed."

# Run the fork
claude -p \
  "${RESUME_FLAGS[@]}" \
  --fork-session \
  --model "$MODEL" \
  --output-format json \
  --allowedTools "$TOOLS" \
  --append-system-prompt "$DELEGATE_PROMPT" \
  < "$PROMPT_FILE" > "$OUT_FILE.raw" 2>"$ERR_FILE" || {
    EXIT_CODE=$?
    echo "Error: claude exited with code $EXIT_CODE" >&2
    if [[ -s "$ERR_FILE" ]]; then
      echo "Stderr:" >&2
      cat "$ERR_FILE" >&2
    fi
    # Still produce output for the caller to read
    if [[ -s "$OUT_FILE.raw" ]]; then
      cp "$OUT_FILE.raw" "$OUT_FILE"
    else
      echo "Fork failed (exit code $EXIT_CODE). Check $ERR_FILE for details." > "$OUT_FILE"
    fi
    echo "FILE: $OUT_FILE"
    echo "PROMPT: $PROMPT_FILE"
    echo "---"
    cat "$OUT_FILE"
    exit $EXIT_CODE
  }

# Extract result from JSON output
if command -v jq &>/dev/null; then
  jq -r '.result // empty' "$OUT_FILE.raw" > "$OUT_FILE" || true
  # Fallback if .result is empty (different JSON structure)
  if [[ ! -s "$OUT_FILE" ]]; then
    cp "$OUT_FILE.raw" "$OUT_FILE"
  fi
else
  cp "$OUT_FILE.raw" "$OUT_FILE"
fi

# Output (same format as ask-ai.sh for composability)
echo "FILE: $OUT_FILE"
echo "PROMPT: $PROMPT_FILE"
echo "---"
cat "$OUT_FILE"

# Cleanup
rm -f "$OUT_FILE.raw"
[[ -s "$ERR_FILE" ]] || rm -f "$ERR_FILE"
