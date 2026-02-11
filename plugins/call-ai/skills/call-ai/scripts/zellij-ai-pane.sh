#!/usr/bin/env bash
# Runs inside a Zellij pane — executes an AI CLI with visible streaming output.
# Launched by ask-ai-zellij.sh via `zellij run`.
#
# Usage:
#   zellij-ai-pane.sh <ai> <model> <prompt-file> <raw-file> <err-file> <done-sentinel> <hold> <hold-error> [<pid-file>]

set -uo pipefail
# Note: not using set -e because we handle exit codes manually

# ─── Arguments ────────────────────────────────────────────────────────────────

AI="${1:?Usage: zellij-ai-pane.sh <ai> <model> <prompt-file> <raw-file> <err-file> <done-sentinel> <hold> <hold-error>}"
MODEL="${2:?}"
PROMPT_FILE="${3:?}"
RAW_FILE="${4:?}"
ERR_FILE="${5:?}"
DONE_SENTINEL="${6:?}"
PANE_HOLD="${7:-30}"
PANE_HOLD_ERROR="${8:-60}"
PID_FILE="${9:-}"

# Tell parent our real PID so it can track liveness
[[ -n "$PID_FILE" ]] && echo $$ > "$PID_FILE.tmp" && mv "$PID_FILE.tmp" "$PID_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ─── Colors ───────────────────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Write exit code to sentinel (atomic: write tmp, then mv)
SENTINEL_WRITTEN=false
write_sentinel() {
  local exit_code="$1"
  [[ "$SENTINEL_WRITTEN" == true ]] && return
  SENTINEL_WRITTEN=true
  echo "$exit_code" > "${DONE_SENTINEL}.tmp"
  mv "${DONE_SENTINEL}.tmp" "$DONE_SENTINEL"
}

# Format number with comma separators
format_number() {
  printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# ─── Session status tracking ─────────────────────────────────────────────────

AI_SESSION_STATUS_DIR="/tmp/ai-session-status"
mkdir -p "$AI_SESSION_STATUS_DIR"
cleanup_stale_sessions
SESSION_STATUS_FILE="$AI_SESSION_STATUS_DIR/${AI}-$$.json"

write_session_status() {
  local status="$1"
  cat > "$SESSION_STATUS_FILE" <<EOF
{"status":"$status","pid":$$,"timestamp":$(date +%s),"ai":"$AI","model":"$MODEL"}
EOF
}

cleanup_session_status() {
  rm -f "$SESSION_STATUS_FILE"
}

# Safety net: always write sentinel on exit so the parent never hangs.
# Normal flow writes it explicitly at line ~241; this catches signals/crashes.
# write_sentinel uses SENTINEL_WRITTEN flag to prevent double-writes (no TOCTOU race).
cleanup_and_write_sentinel() {
  local exit_code=$?
  write_sentinel "${exit_code:-1}"
  cleanup_session_status
}

trap cleanup_and_write_sentinel EXIT INT TERM PIPE

if [[ "$AI" == "gemini" || "$AI" == "codex" ]]; then
  write_session_status "running"
fi

# ─── Banner ───────────────────────────────────────────────────────────────────

AI_UPPER=$(echo "$AI" | tr '[:lower:]' '[:upper:]')
PROMPT_CHARS=$(wc -c < "$PROMPT_FILE" | tr -d ' ')
START_TIME=$(date +%H:%M:%S)

echo ""
echo -e "${BOLD}${CYAN}╭─── ${AI_UPPER} (${MODEL}) ───────────────────────────────────────────╮${RESET}"
echo -e "${BOLD}${CYAN}│${RESET} Started: ${START_TIME} | Prompt: $(format_number "$PROMPT_CHARS") chars"
echo -e "${BOLD}${CYAN}╰──────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# ─── Determine reasoning effort for Codex ─────────────────────────────────────

REASONING_EFFORT="xhigh"
if [[ "$MODEL" == "gpt-5.2-codex" ]]; then
  REASONING_EFFORT="medium"
fi

# ─── CLI smoke test ───────────────────────────────────────────────────────────

case "$AI" in
  codex)  CLI_CMD="codex" ;;
  gemini) CLI_CMD="gemini" ;;
  claude) CLI_CMD="claude" ;;
  *)
    echo -e "${RED}Unknown AI: $AI${RESET}"
    write_sentinel "1"
    exit 1
    ;;
esac

if ! command -v "$CLI_CMD" &>/dev/null; then
  echo -e "${RED}Error: $CLI_CMD CLI not installed${RESET}"
  # Write error JSON to RAW_FILE for consistency
  iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$RAW_FILE" <<EOF
{
  "status": "error",
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "error": {
    "type": "missing_cli",
    "message": "$CLI_CMD CLI not installed",
    "attempts": 0
  },
  "raw_stderr": ""
}
EOF
  write_sentinel "1"
  exit 1
fi

# ─── Run CLI with retries ────────────────────────────────────────────────────

START_TIME_MS=$(get_time_ms)
SUCCESS=false
LAST_ERROR=""
FINAL_EXIT_CODE=1

for (( attempt=1; attempt<=MAX_RETRIES; attempt++ )); do
  if (( attempt > 1 )); then
    echo ""
    echo -e "${YELLOW}─── Retry ${attempt}/${MAX_RETRIES} ─────────────────────────────────────────${RESET}"
    echo ""
  fi

  # Clear previous error file
  > "$ERR_FILE"

  CLI_EXIT=0
  case "$AI" in
    codex)
      RESPONSE_TMP="$RAW_FILE.response"
      codex exec --json \
        -m "$MODEL" \
        -c model_reasoning_effort="$REASONING_EFFORT" \
        -s read-only \
        -c approval_policy="never" \
        --skip-git-repo-check \
        --color never \
        -o "$RESPONSE_TMP" \
        - < "$PROMPT_FILE" 2> >(tee "$ERR_FILE" >&2) \
        | "$SCRIPT_DIR/parse-ai-stream.sh" codex "$RAW_FILE"
      CLI_EXIT=${PIPESTATUS[0]}
      # Fallback: if streaming parser didn't capture output, use -o file
      if [[ ! -s "$RAW_FILE" && -s "$RESPONSE_TMP" ]]; then
        cp "$RESPONSE_TMP" "$RAW_FILE"
      fi
      rm -f "$RESPONSE_TMP"
      ;;
    gemini)
      gemini -m "$MODEL" -y -s -o stream-json \
        --include-directories "$HOME" \
        < "$PROMPT_FILE" 2> >(tee "$ERR_FILE" >&2) \
        | "$SCRIPT_DIR/parse-ai-stream.sh" gemini "$RAW_FILE"
      CLI_EXIT=${PIPESTATUS[0]}
      ;;
    claude)
      claude --model "$MODEL" --print \
        < "$PROMPT_FILE" 2> >(tee "$ERR_FILE" >&2) | tee "$RAW_FILE"
      CLI_EXIT=${PIPESTATUS[0]}
      ;;
  esac

  # Small delay to let process substitution flush
  sleep 0.2

  if [[ $CLI_EXIT -eq 0 && -s "$RAW_FILE" ]]; then
    SUCCESS=true
    FINAL_EXIT_CODE=0
    write_session_status "completed"
    break
  else
    LAST_ERROR=$(head -1 "$ERR_FILE" 2>/dev/null || echo "exit code $CLI_EXIT")

    if (( attempt < MAX_RETRIES )) && is_retryable_error "$ERR_FILE"; then
      WAIT_TIME=$(calculate_backoff $((attempt - 1)))
      echo ""
      echo -e "${YELLOW}[$(date +%H:%M:%S)] Attempt $attempt/$MAX_RETRIES failed: $LAST_ERROR${RESET}"
      echo -e "${DIM}Retrying in ${WAIT_TIME}s...${RESET}"
      sleep "$WAIT_TIME"
    else
      break
    fi
  fi
done

# ─── Footer ──────────────────────────────────────────────────────────────────

END_TIME_MS=$(get_time_ms)
DURATION_MS=$((END_TIME_MS - START_TIME_MS))
DURATION_SEC=$(echo "scale=1; $DURATION_MS / 1000" | bc 2>/dev/null || echo "$((DURATION_MS / 1000))")
RESPONSE_CHARS=0
[[ -f "$RAW_FILE" ]] && RESPONSE_CHARS=$(wc -c < "$RAW_FILE" | tr -d ' ')

echo ""
if [[ "$SUCCESS" == "true" ]]; then
  echo -e "${BOLD}${GREEN}╭─── Complete ─────────────────────────────────────────────────╮${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET} Duration: ${DURATION_SEC}s | Response: $(format_number "$RESPONSE_CHARS") chars | Exit: 0"
  echo -e "${BOLD}${GREEN}╰──────────────────────────────────────────────────────────────╯${RESET}"
else
  write_session_status "failed"
  # Write error JSON if we don't have a valid response
  if [[ ! -s "$RAW_FILE" ]] || ! grep -q '[^[:space:]]' "$RAW_FILE" 2>/dev/null; then
    iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    error_escaped=$(echo "$LAST_ERROR" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')
    raw_stderr=""
    if [[ -f "$ERR_FILE" ]]; then
      raw_stderr=$(cat "$ERR_FILE" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')
    fi
    cat > "$RAW_FILE" <<EOF
{
  "status": "error",
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "error": {
    "type": "unknown",
    "message": "$error_escaped",
    "attempts": $attempt
  },
  "raw_stderr": "$raw_stderr"
}
EOF
  fi

  echo -e "${BOLD}${RED}╭─── Failed ───────────────────────────────────────────────────╮${RESET}"
  echo -e "${BOLD}${RED}│${RESET} Duration: ${DURATION_SEC}s | Attempts: ${attempt} | Error: ${LAST_ERROR:0:40}"
  echo -e "${BOLD}${RED}╰──────────────────────────────────────────────────────────────╯${RESET}"
fi

# ─── Write sentinel ──────────────────────────────────────────────────────────

write_sentinel "$FINAL_EXIT_CODE"

# ─── Hold period (countdown with keyboard control) ───────────────────────────

if [[ "$SUCCESS" == "true" ]]; then
  HOLD_TIME="$PANE_HOLD"
else
  HOLD_TIME="$PANE_HOLD_ERROR"
fi

if (( HOLD_TIME > 0 )); then
  remaining=$HOLD_TIME
  while (( remaining > 0 )); do
    echo -ne "\r${DIM}Closing in ${remaining}s... (q=close, k=keep)${RESET}  "
    if read -rsn1 -t 1 key 2>/dev/null; then
      case "$key" in
        q|Q)
          echo -e "\r${DIM}Closing...                                    ${RESET}"
          break
          ;;
        k|K)
          echo -e "\r${DIM}Pane kept open. Close manually when done.     ${RESET}"
          # Wait indefinitely — user closes pane manually
          while true; do sleep 60; done
          ;;
      esac
    fi
    remaining=$((remaining - 1))
  done
  echo ""
fi
