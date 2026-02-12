#!/usr/bin/env bash
# Zellij-aware wrapper for call-ai skill
# Launches AI CLIs in visible Zellij panes for real-time streaming.
# Falls back to ask-ai.sh when not running inside Zellij.
#
# Usage:
#   ask-ai-zellij.sh <ai> <model> <question>       # Question as argument
#   ask-ai-zellij.sh <ai> <model> -f <file>        # Read question from file
#
#   ai: codex | gemini | claude
#   model: the model name (e.g., gpt-5.3-codex, gemini-3-pro-preview, sonnet)
#
# Environment variables:
#   ZELLIJ_AI_MAX_TIMEOUT      - Max wall-clock seconds before killing pane (default: 1800)
#   ZELLIJ_AI_PANE_HOLD        - Pane hold time after success in seconds (default: 30)
#   ZELLIJ_AI_PANE_HOLD_ON_ERROR - Pane hold time after failure in seconds (default: 60)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR"
source "$SCRIPT_DIR/scripts/common.sh"

# ─── Argument parsing (same interface as ask-ai.sh) ──────────────────────────

AI="${1:-}"
MODEL="${2:-}"
THIRD="${3:-}"
FOURTH="${4:-}"

# Support -f <file> to read prompt from file (avoids CLI argument length limits)
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
  echo "Usage: ask-ai-zellij.sh <ai> <model> <question>" >&2
  echo "       ask-ai-zellij.sh <ai> <model> -f <file>" >&2
  exit 1
fi

# ─── Fallback: not in Zellij → delegate to ask-ai.sh ─────────────────────────

if [[ -z "${ZELLIJ:-}" ]]; then
  exec "$SCRIPT_DIR/ask-ai.sh" "$@"
fi

# ─── Zellij mode ─────────────────────────────────────────────────────────────

# Configuration
POLL_INTERVAL=2
MAX_TIMEOUT="${ZELLIJ_AI_MAX_TIMEOUT:-1800}"
PANE_HOLD="${ZELLIJ_AI_PANE_HOLD:-30}"
PANE_HOLD_ERROR="${ZELLIJ_AI_PANE_HOLD_ON_ERROR:-60}"

# Setup output directory and files (same naming as ask-ai.sh)
# RESPONSES_DIR is set by common.sh
mkdir -p "$RESPONSES_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROMPT_FILE="$RESPONSES_DIR/${AI}-${MODEL}-${TIMESTAMP}-$$.prompt.txt"
RAW_FILE="$RESPONSES_DIR/${AI}-${MODEL}-${TIMESTAMP}-$$.txt"
ERR_FILE="$RAW_FILE.err"
METRICS_FILE="$RAW_FILE.metrics.json"
# METRICS_CSV is set by common.sh
DONE_SENTINEL="$RAW_FILE.done"
PID_FILE="$RAW_FILE.pid"

START_TIME_MS=$(get_time_ms)

# Write prompt to file
echo "$QUESTION" > "$PROMPT_FILE"

# Cleanup temp files on exit; kill pane process if still running
cleanup() {
  local exit_code=$?
  trap - EXIT
  [[ -n "${PANE_PID:-}" ]] && kill "$PANE_PID" 2>/dev/null || true
  rm -f "$DONE_SENTINEL" "${DONE_SENTINEL}.tmp" "$PID_FILE"
  exit $exit_code
}
trap cleanup EXIT INT TERM

# ─── Launch Zellij pane ──────────────────────────────────────────────────────

PANE_SCRIPT="$SCRIPT_DIR/scripts/zellij-ai-pane.sh"

if [[ ! -x "$PANE_SCRIPT" ]]; then
  echo "Error: Pane script not found or not executable: $PANE_SCRIPT" >&2
  echo "Falling back to ask-ai.sh..." >&2
  exec "$SCRIPT_DIR/ask-ai.sh" "$@"
fi

# Launch the pane script in a stacked pane.
# `zellij run` is fire-and-forget — it exits immediately.
# The pane script writes its PID to PID_FILE so we can track the real process.
zellij run --stacked --close-on-exit -- \
  "$PANE_SCRIPT" \
  "$AI" "$MODEL" \
  "$PROMPT_FILE" "$RAW_FILE" "$ERR_FILE" "$DONE_SENTINEL" \
  "$PANE_HOLD" "$PANE_HOLD_ERROR" "$PID_FILE"

START_EPOCH=$(date +%s)
PANE_PID=""

# Helper: write error JSON + metrics + output, then exit
_poll_error_exit() {
  local error_type="$1" error_msg="$2"
  echo "Error: $error_msg ($AI / $MODEL)" >&2

  iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$RAW_FILE" <<EOF
{
  "status": "error",
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "error": {
    "type": "$error_type",
    "message": "$error_msg",
    "attempts": 0
  },
  "raw_stderr": ""
}
EOF

  end_time_ms=$(get_time_ms)
  duration_ms=$((end_time_ms - START_TIME_MS))

  cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "status": "failed",
  "attempts": 0,
  "duration_ms": $duration_ms,
  "response_chars": 0,
  "error": "$error_msg"
}
EOF

  if [[ ! -f "$METRICS_CSV" ]]; then
    echo "timestamp,ai,model,status,attempts,duration_ms,response_chars,error" > "$METRICS_CSV"
  fi
  echo "$iso_timestamp,$AI,$MODEL,failed,0,$duration_ms,0,\"$error_msg\"" >> "$METRICS_CSV"

  echo "FILE: $RAW_FILE"
  echo "PROMPT: $PROMPT_FILE"
  echo "METRICS: $METRICS_FILE"
  echo "---"
  cat "$RAW_FILE"
  exit 1
}

# Phase 1: Wait for pane to register its PID (short timeout — child writes PID immediately)
PID_TIMEOUT=30
while [[ -z "$PANE_PID" ]]; do
  if [[ -f "$PID_FILE" && -s "$PID_FILE" ]]; then
    read -r pid_candidate < "$PID_FILE" || pid_candidate=""
    if [[ "$pid_candidate" =~ ^[0-9]+$ ]]; then
      PANE_PID="$pid_candidate"
    fi
  fi

  now=$(date +%s)
  if (( now - START_EPOCH >= PID_TIMEOUT )); then
    _poll_error_exit "pane_startup_failed" "Pane failed to register PID within ${PID_TIMEOUT}s"
  fi

  sleep "$POLL_INTERVAL"
done

# Phase 2: Monitor real pane process
while [[ ! -f "$DONE_SENTINEL" ]]; do
  # PID liveness — real crash detection
  # Re-check sentinel after kill -0 fails to avoid race where process wrote sentinel then exited
  if ! kill -0 "$PANE_PID" 2>/dev/null; then
    [[ -f "$DONE_SENTINEL" ]] && break
    _poll_error_exit "process_crash" "Pane process crashed (PID $PANE_PID died without writing sentinel)"
  fi

  # Wall-clock safety net
  now=$(date +%s)
  if (( now - START_EPOCH >= MAX_TIMEOUT )); then
    kill "$PANE_PID" 2>/dev/null || true
    _poll_error_exit "wall_timeout" "Wall-clock timeout (exceeded ${MAX_TIMEOUT}s)"
  fi

  sleep "$POLL_INTERVAL"
done

# ─── Pane completed — read exit code from sentinel ───────────────────────────

PANE_EXIT_CODE=$(cat "$DONE_SENTINEL" 2>/dev/null || echo "1")

# ─── Write metrics ───────────────────────────────────────────────────────────

end_time_ms=$(get_time_ms)
duration_ms=$((end_time_ms - START_TIME_MS))
response_chars=0
[[ -f "$RAW_FILE" ]] && response_chars=$(wc -c < "$RAW_FILE" | tr -d ' ')
iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$PANE_EXIT_CODE" == "0" ]]; then
  status="success"
  error_json="null"
  error_csv=""
else
  status="failed"
  error_msg=""
  if [[ -f "$ERR_FILE" ]]; then
    error_msg=$(head -1 "$ERR_FILE" 2>/dev/null || echo "exit code $PANE_EXIT_CODE")
  else
    error_msg="exit code $PANE_EXIT_CODE"
  fi
  error_json="\"$(echo "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')\""
  error_csv="\"$(echo "$error_msg" | sed 's/"/""/g' | tr -d '\n')\""
fi

# JSON sidecar
cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$iso_timestamp",
  "ai": "$AI",
  "model": "$MODEL",
  "status": "$status",
  "attempts": 1,
  "duration_ms": $duration_ms,
  "response_chars": $response_chars,
  "error": $error_json
}
EOF

# CSV append
if [[ ! -f "$METRICS_CSV" ]]; then
  echo "timestamp,ai,model,status,attempts,duration_ms,response_chars,error" > "$METRICS_CSV"
fi
echo "$iso_timestamp,$AI,$MODEL,$status,1,$duration_ms,$response_chars,$error_csv" >> "$METRICS_CSV"

# Clean up error file if empty
[[ -s "$ERR_FILE" ]] || rm -f "$ERR_FILE"

# ─── Output results (same format as ask-ai.sh) ──────────────────────────────

echo "FILE: $RAW_FILE"
echo "PROMPT: $PROMPT_FILE"
echo "METRICS: $METRICS_FILE"
echo "---"
cat "$RAW_FILE"
