#!/usr/bin/env bash
# Shared helper functions for call-ai scripts.
# Source this file: source "$(dirname "$0")/scripts/common.sh"
#   or from scripts/: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Skill root directory (portable — works regardless of install location)
SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Retry configuration
MAX_RETRIES=3
BACKOFF_TIMES=(10 20 40)

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

# Calculate backoff with ±10% jitter
calculate_backoff() {
  local base="${BACKOFF_TIMES[$1]}"
  local jitter=$(( base / 10 ))
  local random_jitter=$(( (RANDOM % (jitter * 2 + 1)) - jitter ))
  echo $(( base + random_jitter ))
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
  local responses_dir="$SKILL_DIR/.responses"
  [[ -d "$responses_dir" ]] && find "$responses_dir" -name "*.pid" -mmin +60 -delete 2>/dev/null || true
}
