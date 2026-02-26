#!/usr/bin/env bash
# Runs multiple AI calls in parallel and collects results.
#
# Usage:
#   run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]
#
# Each ai/model pair is launched as a background process via ask-ai-runner.sh
# (which selects zellij/tmux/ghostty/headless by environment and availability).
#
# Results are output with clear delimiters:
#   === RESULT: <ai> <model> ===
#   [captured stdout]
#   === END: <ai> <model> ===
#
# Environment variables:
#   AI_MAX_TIMEOUT              - Max wall-clock seconds before killing a process (default: 1800)
#   AI_POLL_INTERVAL            - Seconds between liveness checks (default: 3)
#   ZELLIJ_AI_SIDE_STACK_LAYOUT - In Zellij with multiple AIs, 1 enables:
#                                 current pane on left + AI stack on right (default: 1)
#   ZELLIJ_AI_LAYOUT_SETTLE_SECS - Delay between pane launches for layout stability (default: 0.2)

set -uo pipefail
# Note: not using set -e because we handle exit codes manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source common.sh for config (sets SKILL_DIR, METRICS_CSV, etc.)
source "$SCRIPT_DIR/common.sh"

# ─── Arguments ─────────────────────────────────────────────────────────────────

PROMPT_FILE="${1:?Usage: run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]}"
shift

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if (( $# < 2 )) || (( $# % 2 != 0 )); then
  echo "Error: Expected ai/model pairs after prompt file" >&2
  echo "Usage: run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]" >&2
  exit 1
fi

# ─── Configuration ─────────────────────────────────────────────────────────────

MAX_TIMEOUT="${AI_MAX_TIMEOUT:-1800}"
POLL_INTERVAL="${AI_POLL_INTERVAL:-3}"
SIDE_STACK_LAYOUT="${ZELLIJ_AI_SIDE_STACK_LAYOUT:-1}"
LAYOUT_SETTLE_SECS="${ZELLIJ_AI_LAYOUT_SETTLE_SECS:-0.2}"

# ─── Work directory ────────────────────────────────────────────────────────────

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/run-parallel.XXXXXX")

cleanup() {
  # Kill any remaining children
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

# ─── Parse ai/model pairs ─────────────────────────────────────────────────────

declare -a AI_NAMES=()
declare -a MODEL_NAMES=()
declare -a PIDS=()
declare -a EXIT_CODES=()
declare -a OUT_FILES=()

while (( $# >= 2 )); do
  AI_NAMES+=("$1")
  MODEL_NAMES+=("$2")
  shift 2
done

# In Zellij with multiple AIs, create a right-side AI stack by default:
# - first launch: split right (non-stacked)
# - subsequent launches: stacked in that right pane
USE_ZELLIJ_SIDE_STACK=0
if [[ -n "${ZELLIJ:-}" ]] && [[ "$SIDE_STACK_LAYOUT" != "0" ]] && (( ${#AI_NAMES[@]} > 1 )); then
  USE_ZELLIJ_SIDE_STACK=1
fi

# ─── Pre-create metrics CSV header (avoids race between parallel children) ────

# METRICS_CSV is set by common.sh
mkdir -p "$(dirname "$METRICS_CSV")"
if [[ ! -f "$METRICS_CSV" ]]; then
  echo "timestamp,ai,model,status,attempts,duration_ms,response_chars,error" > "$METRICS_CSV"
fi

# ─── Launch all processes ──────────────────────────────────────────────────────

for i in "${!AI_NAMES[@]}"; do
  ai="${AI_NAMES[i]}"
  model="${MODEL_NAMES[i]}"
  out_file="$WORK_DIR/${i}-${ai}-${model}.out"
  OUT_FILES+=("$out_file")

  # Launch in background — capture stdout and stderr to separate files
  # (Standard redirection > and 2> creates the files immediately)
  if (( USE_ZELLIJ_SIDE_STACK == 1 )); then
    if (( i == 0 )); then
      ZELLIJ_AI_STACKED="0" ZELLIJ_AI_DIRECTION="right" \
        "$SKILL_DIR/ask-ai-runner.sh" "$ai" "$model" -f "$PROMPT_FILE" \
        > "$out_file" 2>"$WORK_DIR/${i}-${ai}-${model}.err" &
    else
      ZELLIJ_AI_STACKED="1" ZELLIJ_AI_DIRECTION="" \
        "$SKILL_DIR/ask-ai-runner.sh" "$ai" "$model" -f "$PROMPT_FILE" \
        > "$out_file" 2>"$WORK_DIR/${i}-${ai}-${model}.err" &
    fi
  else
    "$SKILL_DIR/ask-ai-runner.sh" "$ai" "$model" -f "$PROMPT_FILE" \
      > "$out_file" 2>"$WORK_DIR/${i}-${ai}-${model}.err" &
  fi

  PIDS+=($!)
  EXIT_CODES+=("0")

  if (( USE_ZELLIJ_SIDE_STACK == 1 )) && (( i < ${#AI_NAMES[@]} - 1 )); then
    sleep "$LAYOUT_SETTLE_SECS"
  fi
done

echo "[parallel] Launched ${#PIDS[@]} AI processes" >&2

# ─── Monitor liveness per-process ──────────────────────────────────────────────

declare -a ALIVE=()
for i in "${!PIDS[@]}"; do
  ALIVE+=("1")
done

START_EPOCH=$(date +%s)

while true; do
  all_done=true
  now=$(date +%s)

  for i in "${!PIDS[@]}"; do
    [[ "${ALIVE[i]}" == "0" ]] && continue

    pid="${PIDS[i]}"

    # Check if process exited
    if ! kill -0 "$pid" 2>/dev/null; then
      ALIVE[i]="0"
      wait "$pid" 2>/dev/null
      EXIT_CODES[i]=$?
      continue
    fi

    all_done=false

    # Safety net: kill if exceeds max wall-clock time
    if (( now - START_EPOCH >= MAX_TIMEOUT )); then
      ai="${AI_NAMES[i]}"
      model="${MODEL_NAMES[i]}"
      echo "[parallel] Killing: $ai $model (exceeded ${MAX_TIMEOUT}s wall-clock limit)" >&2
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null
      EXIT_CODES[i]=$?
      ALIVE[i]="0"
    fi
  done

  [[ "$all_done" == "true" ]] && break
  sleep "$POLL_INTERVAL"
done

# Wait for all children to fully exit
wait 2>/dev/null || true

echo "[parallel] All processes complete" >&2

# ─── Collect and output results ────────────────────────────────────────────────

for i in "${!AI_NAMES[@]}"; do
  ai="${AI_NAMES[i]}"
  model="${MODEL_NAMES[i]}"
  out_file="${OUT_FILES[i]}"
  err_file="$WORK_DIR/${i}-${ai}-${model}.err"
  exit_code="${EXIT_CODES[i]}"

  echo "=== RESULT: $ai $model ==="
  if [[ -s "$out_file" ]]; then
    cat "$out_file"
  else
    echo "[no output]"
  fi

  # Include stderr if the process failed OR if stdout was empty (to show potential warnings)
  if [[ -s "$err_file" ]]; then
    if [[ "$exit_code" != "0" ]] || [[ ! -s "$out_file" ]]; then
      echo ""
      echo "[stderr]"
      cat "$err_file"
    fi
  fi
  echo "=== END: $ai $model ==="
  echo ""
done

# ─── Propagate failure ────────────────────────────────────────────────────────

for exit_code in "${EXIT_CODES[@]}"; do
  if [[ "$exit_code" != "0" ]]; then
    exit 1
  fi
done
