#!/usr/bin/env bash
# Runs multiple AI calls in parallel and collects results.
#
# Usage:
#   run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]
#   run-parallel.sh --spec <ai-spec> <prompt-file>
#   run-parallel.sh --list-specs
#
# Supported --spec values:
#   default (or empty)          -> codex+gemini (thorough)
#   codex | gemini | claude     -> single thorough
#   codex+gemini | codex+claude | gemini+claude (any order; + , / separators)
#   :trio                       -> codex+gemini+claude (thorough)
#   :all                        -> all 3 providers x thorough+fast
#   aliases                     -> :cg, :cc, :gc
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

usage() {
  cat >&2 <<'EOF'
Usage:
  run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]
  run-parallel.sh --spec <ai-spec> <prompt-file>
  run-parallel.sh --list-specs

Examples:
  run-parallel.sh prompt.xml codex gpt-5.3-codex gemini gemini-3-pro-preview
  run-parallel.sh --spec gemini+claude prompt.xml
  run-parallel.sh --spec :all prompt.xml

Supported ai-spec values:
  default (or empty), codex, gemini, claude,
  codex+gemini, codex+claude, gemini+claude,
  :trio, :all, :cg, :cc, :gc
EOF
}

list_specs() {
  cat <<'EOF'
default
codex
gemini
claude
codex+gemini
codex+claude
gemini+claude
:trio
:all
:cg
:cc
:gc
EOF
}

load_models_from_registry() {
  local registry="$SKILL_DIR/ai-registry.yaml"
  if [[ ! -f "$registry" ]]; then
    echo "Error: ai-registry.yaml not found at $registry" >&2
    exit 1
  fi

  eval "$(python3 - "$registry" <<'PY'
import shlex
import sys

path = sys.argv[1]
providers = {"codex": {}, "gemini": {}, "claude": {}}
in_providers = False
current = None
in_models = False

with open(path, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip(" "))

        if indent == 0 and stripped == "providers:":
            in_providers = True
            current = None
            in_models = False
            continue

        if not in_providers:
            continue

        if indent == 0 and stripped.endswith(":") and stripped != "providers:":
            # End of providers section
            in_providers = False
            current = None
            in_models = False
            continue

        if indent == 2 and stripped.endswith(":"):
            key = stripped[:-1]
            current = key if key in providers else None
            in_models = False
            continue

        if current is None:
            continue

        if indent == 4 and stripped == "models:":
            in_models = True
            continue

        if in_models and indent == 6 and ":" in stripped:
            k, v = stripped.split(":", 1)
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k in ("thorough", "fast"):
                providers[current][k] = v
            continue

required = [
    ("CODEX_THOROUGH", providers["codex"].get("thorough", "")),
    ("CODEX_FAST", providers["codex"].get("fast", "")),
    ("GEMINI_THOROUGH", providers["gemini"].get("thorough", "")),
    ("GEMINI_FAST", providers["gemini"].get("fast", "")),
    ("CLAUDE_THOROUGH", providers["claude"].get("thorough", "")),
    ("CLAUDE_FAST", providers["claude"].get("fast", "")),
]

for k, v in required:
    print(f"{k}={shlex.quote(v)}")
PY
)"

  for var in CODEX_THOROUGH CODEX_FAST GEMINI_THOROUGH GEMINI_FAST CLAUDE_THOROUGH CLAUDE_FAST; do
    if [[ -z "${!var:-}" ]]; then
      echo "Error: Missing $var in ai-registry.yaml" >&2
      exit 1
    fi
  done
}

declare -a SPEC_PAIRS=()

resolve_spec_pairs() {
  local raw_spec="${1:-}"
  local spec="${raw_spec,,}"
  spec="${spec// /}"

  # Aliases
  case "$spec" in
    ":cg"|"cg") spec="codex+gemini" ;;
    ":cc"|"cc") spec="codex+claude" ;;
    ":gc"|"gc") spec="gemini+claude" ;;
  esac

  # Simple specs
  case "$spec" in
    ""|"default"|":default")
      SPEC_PAIRS=(codex "$CODEX_THOROUGH" gemini "$GEMINI_THOROUGH")
      return 0
      ;;
    ":all"|"all")
      SPEC_PAIRS=(
        codex "$CODEX_THOROUGH"
        codex "$CODEX_FAST"
        gemini "$GEMINI_THOROUGH"
        gemini "$GEMINI_FAST"
        claude "$CLAUDE_THOROUGH"
        claude "$CLAUDE_FAST"
      )
      return 0
      ;;
    ":trio"|"trio")
      SPEC_PAIRS=(
        codex "$CODEX_THOROUGH"
        gemini "$GEMINI_THOROUGH"
        claude "$CLAUDE_THOROUGH"
      )
      return 0
      ;;
    "codex")
      SPEC_PAIRS=(codex "$CODEX_THOROUGH")
      return 0
      ;;
    "gemini")
      SPEC_PAIRS=(gemini "$GEMINI_THOROUGH")
      return 0
      ;;
    "claude")
      SPEC_PAIRS=(claude "$CLAUDE_THOROUGH")
      return 0
      ;;
  esac

  # Combination forms: + , /
  local combo="$spec"
  combo="${combo//,/+}"
  combo="${combo//\//+}"

  if [[ "$combo" == *"+"* ]]; then
    local codex_on=0
    local gemini_on=0
    local claude_on=0

    IFS='+' read -r -a parts <<< "$combo"
    for part in "${parts[@]}"; do
      [[ -z "$part" ]] && continue
      case "$part" in
        codex) codex_on=1 ;;
        gemini) gemini_on=1 ;;
        claude) claude_on=1 ;;
        *)
          echo "Error: Unknown provider in ai-spec: $part" >&2
          return 1
          ;;
      esac
    done

    local count=$((codex_on + gemini_on + claude_on))

    if (( count == 3 )); then
      SPEC_PAIRS=(
        codex "$CODEX_THOROUGH"
        gemini "$GEMINI_THOROUGH"
        claude "$CLAUDE_THOROUGH"
      )
      return 0
    fi

    if (( count == 2 )); then
      SPEC_PAIRS=()
      (( codex_on )) && SPEC_PAIRS+=(codex "$CODEX_THOROUGH")
      (( gemini_on )) && SPEC_PAIRS+=(gemini "$GEMINI_THOROUGH")
      (( claude_on )) && SPEC_PAIRS+=(claude "$CLAUDE_THOROUGH")
      return 0
    fi

    if (( count == 1 )); then
      if (( codex_on )); then
        SPEC_PAIRS=(codex "$CODEX_THOROUGH")
      elif (( gemini_on )); then
        SPEC_PAIRS=(gemini "$GEMINI_THOROUGH")
      else
        SPEC_PAIRS=(claude "$CLAUDE_THOROUGH")
      fi
      return 0
    fi
  fi

  echo "Error: Unsupported ai-spec '$raw_spec'" >&2
  echo "Tip: run --list-specs to view supported values" >&2
  return 1
}

# ─── Arguments ─────────────────────────────────────────────────────────────────

if (( $# == 0 )); then
  usage
  exit 1
fi

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --list-specs)
    list_specs
    exit 0
    ;;
  --spec)
    if (( $# < 3 )); then
      usage
      exit 1
    fi
    SPEC="$2"
    PROMPT_FILE="$3"
    shift 3

    if (( $# > 0 )); then
      echo "Error: --spec mode does not accept extra ai/model arguments" >&2
      usage
      exit 1
    fi

    load_models_from_registry
    resolve_spec_pairs "$SPEC" || exit 1
    set -- "${SPEC_PAIRS[@]}"
    ;;
  *)
    PROMPT_FILE="$1"
    shift
    ;;
esac

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if (( $# < 2 )) || (( $# % 2 != 0 )); then
  echo "Error: Expected ai/model pairs after prompt file" >&2
  usage
  exit 1
fi

# ─── Configuration ─────────────────────────────────────────────────────────────

MAX_TIMEOUT="${AI_MAX_TIMEOUT:-1800}"
POLL_INTERVAL="${AI_POLL_INTERVAL:-3}"
SIDE_STACK_LAYOUT="${ZELLIJ_AI_SIDE_STACK_LAYOUT:-1}"
LAYOUT_SETTLE_SECS="${ZELLIJ_AI_LAYOUT_SETTLE_SECS:-0.2}"

# ─── Work directory ────────────────────────────────────────────────────────────

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/run-parallel.XXXXXX")

declare -a AI_NAMES=()
declare -a MODEL_NAMES=()
declare -a PIDS=()
declare -a EXIT_CODES=()
declare -a OUT_FILES=()

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
