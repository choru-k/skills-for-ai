#!/usr/bin/env bash
# Wrapper script for call-ai skill
# Usage:
#   ask-ai.sh <ai> <model> <question>       # Question as argument
#   ask-ai.sh <ai> <model> -f <file>        # Read question from file
#
#   ai: codex | gemini | claude
#   model: the model name (e.g., gpt-5.3-codex, gemini-3-pro-preview, sonnet)
#
# Prompts are written to a file and piped via stdin to avoid CLI argument length limits.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR"
source "$SCRIPT_DIR/scripts/common.sh"

# Log retry attempt
log_retry() {
  local attempt="$1"
  local max="$2"
  local wait="$3"
  local reason="$4"
  echo "[$(date +%H:%M:%S)] Attempt $attempt/$max failed: $reason. Retrying in ${wait}s..." >&2
}

# Write metrics to JSON sidecar and CSV log
write_metrics() {
  local status="$1"
  local attempts="$2"
  local error="${3:-}"

  local end_time_ms
  end_time_ms=$(get_time_ms)
  local duration_ms=$((end_time_ms - START_TIME_MS))
  local response_chars=0
  [[ -f "$RAW_FILE" ]] && response_chars=$(wc -c < "$RAW_FILE" | tr -d ' ')
  local iso_timestamp
  iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # JSON sidecar - proper escaping for error messages
  local error_json="null"
  if [[ -n "$error" ]]; then
    # Escape quotes and backslashes for JSON
    error_json="\"$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')\""
  fi

  cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "status": "$status",
  "attempts": $attempts,
  "duration_ms": $duration_ms,
  "response_chars": $response_chars,
  "error": $error_json
}
EOF

  # CSV append log (create header if new file)
  if [[ ! -f "$METRICS_CSV" ]]; then
    echo "timestamp,ai,model,status,attempts,duration_ms,response_chars,error" > "$METRICS_CSV"
  fi
  # Escape error for CSV (double quotes, wrap in quotes)
  local error_csv=""
  if [[ -n "$error" ]]; then
    error_csv="\"$(echo "$error" | sed 's/"/""/g' | tr -d '\n')\""
  fi
  echo "$iso_timestamp,$AI,$MODEL,$status,$attempts,$duration_ms,$response_chars,$error_csv" >> "$METRICS_CSV"
}

# Classify error type from error message/file
classify_error() {
  local err_msg="$1"
  local err_file="$2"
  local combined="$err_msg"
  [[ -f "$err_file" ]] && combined="$combined $(cat "$err_file")"

  if echo "$combined" | grep -qiE "(timeout|ETIMEDOUT)"; then
    echo "timeout"
  elif echo "$combined" | grep -qiE "(429|rate.?limit|quota)"; then
    echo "rate_limit"
  elif echo "$combined" | grep -qiE "(connection|ECONNRESET|ECONNREFUSED|network)"; then
    echo "connection"
  elif echo "$combined" | grep -qiE "(401|403|unauthorized|forbidden|auth)"; then
    echo "auth"
  elif echo "$combined" | grep -qiE "(400|invalid|malformed)"; then
    echo "bad_request"
  elif echo "$combined" | grep -qiE "(500|502|503|504|server)"; then
    echo "server_error"
  elif echo "$combined" | grep -qiE "(not installed|not found|command not found)"; then
    echo "missing_cli"
  else
    echo "unknown"
  fi
}

# Write structured JSON error to RAW_FILE
write_error_json() {
  local ai="$1"
  local model="$2"
  local attempts="$3"
  local error_msg="$4"
  local err_file="$5"

  local error_type
  error_type=$(classify_error "$error_msg" "$err_file")
  local iso_timestamp
  iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Escape error message for JSON
  local error_escaped
  error_escaped=$(echo "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')

  # Capture raw stderr if available
  local raw_stderr=""
  if [[ -f "$err_file" ]]; then
    raw_stderr=$(cat "$err_file" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')
  fi

  cat > "$RAW_FILE" <<EOF
{
  "status": "error",
  "timestamp": "$iso_timestamp",
  "ai": "$ai",
  "model": "$model",
  "error": {
    "type": "$error_type",
    "message": "$error_escaped",
    "attempts": $attempts
  },
  "raw_stderr": "$raw_stderr"
}
EOF
}

# Smoke test: check if CLI is available before attempting retries
check_cli() {
  local cli="$1"
  if ! command -v "$cli" &>/dev/null; then
    write_error_json "$AI" "$MODEL" "0" "$cli CLI not installed" "/dev/null"
    write_metrics "failed" "0" "missing_cli: $cli"
    echo "FILE: $RAW_FILE"
    echo "PROMPT: $PROMPT_FILE"
    echo "METRICS: $METRICS_FILE"
    echo "---"
    cat "$RAW_FILE"
    exit 1
  fi
}

AI="${1:-}"
MODEL="${2:-}"
THIRD="${3:-}"
FOURTH="${4:-}"

# Support -f <file> to read prompt from file (avoids CLI arg length limits)
if [[ "$THIRD" == "-f" && -n "$FOURTH" ]]; then
  if [[ ! -f "$FOURTH" ]]; then
    echo "Error: File not found: $FOURTH" >&2
    exit 1
  fi
  QUESTION=$(cat "$FOURTH")
else
  QUESTION="$THIRD"
fi

if [[ -z "$AI" || -z "$MODEL" || -z "$QUESTION" ]]; then
  echo "Usage: ask-ai.sh <ai> <model> <question>" >&2
  echo "       ask-ai.sh <ai> <model> -f <file>" >&2
  exit 1
fi

# Setup output directory and files
# RESPONSES_DIR is set by common.sh
mkdir -p "$RESPONSES_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROMPT_FILE="$RESPONSES_DIR/${AI}-${MODEL}-${TIMESTAMP}-$$.prompt.txt"
RAW_FILE="$RESPONSES_DIR/${AI}-${MODEL}-${TIMESTAMP}-$$.txt"
ERR_FILE="$RAW_FILE.err"

# Metrics: capture start time and setup paths
START_TIME_MS=$(get_time_ms)
METRICS_FILE="$RAW_FILE.metrics.json"
# METRICS_CSV is set by common.sh

# Write prompt to file (for debugging and to pipe via stdin)
echo "$QUESTION" > "$PROMPT_FILE"

# Status tracking for AI session monitoring (Sketchybar integration)
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

# Only track Gemini and Codex (Claude has its own hooks)
if [[ "$AI" == "gemini" || "$AI" == "codex" ]]; then
  trap cleanup_session_status EXIT
  write_session_status "running"
fi

case "$AI" in
  codex)
    check_cli "codex"
    RESPONSE_TMP="$RAW_FILE.response"
    SUCCESS=false
    LAST_ERROR=""

    # Determine reasoning effort based on model (fast=medium, thorough=xhigh)
    REASONING_EFFORT="xhigh"
    if [[ "$MODEL" == "gpt-5.2-codex" ]]; then
      REASONING_EFFORT="medium"
    fi

    for (( attempt=1; attempt<=MAX_RETRIES; attempt++ )); do
      if codex exec \
        -m "$MODEL" \
        -c model_reasoning_effort="$REASONING_EFFORT" \
        -s read-only \
        -c approval_policy="never" \
        --skip-git-repo-check \
        --color never \
        -o "$RESPONSE_TMP" \
        - < "$PROMPT_FILE" 2>"$ERR_FILE"; then
        # Success
        cat "$RESPONSE_TMP" > "$RAW_FILE"
        SUCCESS=true
        write_metrics "success" "$attempt"
        write_session_status "completed"
        break
      else
        EXIT_CODE=$?
        LAST_ERROR=$(head -1 "$ERR_FILE" 2>/dev/null || echo "exit code $EXIT_CODE")

        # Check if we should retry
        if (( attempt < MAX_RETRIES )) && is_retryable_error "$ERR_FILE"; then
          WAIT_TIME=$(calculate_backoff $((attempt - 1)))
          log_retry "$attempt" "$MAX_RETRIES" "$WAIT_TIME" "$LAST_ERROR"
          sleep "$WAIT_TIME"
        else
          break
        fi
      fi
    done

    if [[ "$SUCCESS" != "true" ]]; then
      write_metrics "failed" "$attempt" "$LAST_ERROR"
      write_error_json "$AI" "$MODEL" "$attempt" "$LAST_ERROR" "$ERR_FILE"
      write_session_status "failed"
    fi
    rm -f "$RESPONSE_TMP"
    ;;

  gemini)
    check_cli "gemini"
    RESPONSE_TMP="$RAW_FILE.response"
    SUCCESS=false
    LAST_ERROR=""

    for (( attempt=1; attempt<=MAX_RETRIES; attempt++ )); do
      # Use -o text for clean output (no jq needed)
      if gemini -m "$MODEL" -y -s -o text \
        < "$PROMPT_FILE" > "$RESPONSE_TMP" 2>"$ERR_FILE"; then
        cat "$RESPONSE_TMP" > "$RAW_FILE"
        SUCCESS=true
        write_metrics "success" "$attempt"
        write_session_status "completed"
        break
      else
        EXIT_CODE=$?
        LAST_ERROR=$(head -1 "$ERR_FILE" 2>/dev/null || echo "exit code $EXIT_CODE")

        # Check if we should retry
        if (( attempt < MAX_RETRIES )) && is_retryable_error "$ERR_FILE"; then
          WAIT_TIME=$(calculate_backoff $((attempt - 1)))
          log_retry "$attempt" "$MAX_RETRIES" "$WAIT_TIME" "$LAST_ERROR"
          sleep "$WAIT_TIME"
        else
          break
        fi
      fi
    done

    if [[ "$SUCCESS" != "true" ]]; then
      write_metrics "failed" "$attempt" "$LAST_ERROR"
      write_error_json "$AI" "$MODEL" "$attempt" "$LAST_ERROR" "$ERR_FILE"
      write_session_status "failed"
    fi
    rm -f "$RESPONSE_TMP"
    ;;

  claude)
    check_cli "claude"
    RESPONSE_TMP="$RAW_FILE.response"
    SUCCESS=false
    LAST_ERROR=""

    for (( attempt=1; attempt<=MAX_RETRIES; attempt++ )); do
      # Use --print for non-interactive output, pipe prompt via stdin
      if claude --model "$MODEL" --print \
        < "$PROMPT_FILE" > "$RESPONSE_TMP" 2>"$ERR_FILE"; then
        cat "$RESPONSE_TMP" > "$RAW_FILE"
        SUCCESS=true
        write_metrics "success" "$attempt"
        break
      else
        EXIT_CODE=$?
        LAST_ERROR=$(head -1 "$ERR_FILE" 2>/dev/null || echo "exit code $EXIT_CODE")

        # Check if we should retry
        if (( attempt < MAX_RETRIES )) && is_retryable_error "$ERR_FILE"; then
          WAIT_TIME=$(calculate_backoff $((attempt - 1)))
          log_retry "$attempt" "$MAX_RETRIES" "$WAIT_TIME" "$LAST_ERROR"
          sleep "$WAIT_TIME"
        else
          break
        fi
      fi
    done

    if [[ "$SUCCESS" != "true" ]]; then
      write_metrics "failed" "$attempt" "$LAST_ERROR"
      write_error_json "$AI" "$MODEL" "$attempt" "$LAST_ERROR" "$ERR_FILE"
    fi
    rm -f "$RESPONSE_TMP"
    ;;

  *)
    echo "Unknown AI: $AI (expected: codex, gemini, claude)" >&2
    exit 1
    ;;
esac

# Clean up error file if empty
[[ -s "$ERR_FILE" ]] || rm -f "$ERR_FILE"

# Output results
echo "FILE: $RAW_FILE"
echo "PROMPT: $PROMPT_FILE"
echo "METRICS: $METRICS_FILE"
echo "---"
cat "$RAW_FILE"
