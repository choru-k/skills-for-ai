#!/usr/bin/env bash
# Shared helper functions for call-ai scripts.
# Source this file: source "$(dirname "$0")/scripts/common.sh"
#   or from scripts/: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Skill root directory (portable — works regardless of install location)
SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── Config defaults (overridden by ai-registry.yaml, then env vars) ─────────

RESPONSES_DIR_NAME=".responses"
METRICS_LOG_NAME="metrics.csv"
MAX_RETRIES=3
BACKOFF_TIMES=(10 20 40)
JITTER_PERCENT=10

# ─── Load config from ai-registry.yaml (python3 stdlib, section-aware) ───────

load_config() {
  local config_file="$SKILL_DIR/ai-registry.yaml"
  [[ -f "$config_file" ]] || return 0

  eval "$(python3 -c "
import sys
section = ''
try:
    with open(sys.argv[1]) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            indent = len(line) - len(line.lstrip())
            if indent == 0 and stripped.endswith(':'):
                section = stripped[:-1]
                continue
            if ':' not in stripped:
                continue
            k, v = stripped.split(':', 1)
            k, v = k.strip(), v.strip().strip('\"').strip(\"'\")
            if section == 'retry':
                if k == 'max_attempts' and v.isdigit():
                    print(f'MAX_RETRIES={v}')
                elif k == 'backoff_seconds':
                    nums = v.strip('[]').replace(',', ' ')
                    if all(n.strip().isdigit() for n in nums.split()):
                        print(f'BACKOFF_TIMES=({nums})')
                elif k == 'jitter_percent' and v.isdigit():
                    print(f'JITTER_PERCENT={v}')
            elif section == 'storage':
                if k == 'directory':
                    print(f'RESPONSES_DIR_NAME=\"{v}\"')
                elif k == 'metrics_log':
                    print(f'METRICS_LOG_NAME=\"{v}\"')
except Exception:
    pass
" "$config_file" 2>/dev/null)" || true
}

load_config

# ─── Apply env var overrides (highest precedence) ────────────────────────────

MAX_RETRIES="${AI_MAX_RETRIES:-$MAX_RETRIES}"
BACKOFF_TIMES=(${AI_BACKOFF_TIMES:-${BACKOFF_TIMES[@]}})
JITTER_PERCENT="${AI_JITTER_PERCENT:-$JITTER_PERCENT}"
RESPONSES_DIR="${AI_RESPONSES_DIR:-$SKILL_DIR/$RESPONSES_DIR_NAME}"
METRICS_CSV="$RESPONSES_DIR/${AI_METRICS_LOG:-$METRICS_LOG_NAME}"

# Export for child scripts
export SKILL_DIR MAX_RETRIES BACKOFF_TIMES RESPONSES_DIR METRICS_CSV JITTER_PERCENT

# ─── Helper Functions ──────────────────────────────────────────────────────────

# Get current time in milliseconds (macOS compatible)
get_time_ms() {
  if command -v gdate &>/dev/null; then
    echo $(($(gdate +%s%N) / 1000000))
  elif command -v perl &>/dev/null; then
    perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
  else
    # Fallback to seconds * 1000
    echo $(($(date +%s) * 1000))
  fi
}

# Calculate backoff with configured jitter
calculate_backoff() {
  local attempt_idx="$1"
  # Default to last value if index out of bounds
  local base
  if (( attempt_idx < ${#BACKOFF_TIMES[@]} )); then
    base="${BACKOFF_TIMES[$attempt_idx]}"
  else
    base="${BACKOFF_TIMES[-1]}"
  fi
  
  local jitter=$(( base * JITTER_PERCENT / 100 ))
  # Avoid division by zero if jitter is 0
  if (( jitter == 0 )); then
    echo "$base"
  else
    local random_jitter=$(( (RANDOM % (jitter * 2 + 1)) - jitter ))
    echo $(( base + random_jitter ))
  fi
}

# Check if error is retryable
is_retryable_error() {
  local err_file="$1"
  if [[ ! -f "$err_file" ]]; then
    return 1  # No error file, not retryable
  fi
  # Retryable: timeout, rate limit, connection errors
  grep -qiE "(timeout|429|rate.?limit|connection|ECONNRESET|ETIMEDOUT)" "$err_file"
}

# Clean up stale session status files (older than 10 minutes)
# and orphaned PID files (older than 60 minutes)
cleanup_stale_sessions() {
  local status_dir="/tmp/ai-session-status"
  [[ -d "$status_dir" ]] && find "$status_dir" -name "*.json" -mmin +10 -delete 2>/dev/null || true
  
  if [[ -d "$RESPONSES_DIR" ]]; then
    find "$RESPONSES_DIR" -name "*.pid" -mmin +60 -delete 2>/dev/null || true
  fi
}
