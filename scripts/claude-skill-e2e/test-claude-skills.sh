#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS="$SCRIPT_DIR/claude-skill-harness.py"
CASES_DIR_DEFAULT="$SCRIPT_DIR/cases"
OUTPUT_DIR_DEFAULT="$REPO_ROOT/.responses/claude-skill-harness"

if [[ ! -x "$HARNESS" ]]; then
  echo "Error: harness script not found or not executable: $HARNESS" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required" >&2
  exit 1
fi

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
OUTPUT_DIR="$OUTPUT_DIR_DEFAULT"
CASE_FILE=""
CASES_DIR="$CASES_DIR_DEFAULT"
SKILL_NAME=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [--case <case.json>] [--skill <skill-name>] [--dir <cases-dir>] [--output-dir <dir>] [--claude-bin <path>]

Modes:
  --case <file>   Run one explicit case file
  --skill <name>  Run all cases under:
                  - skills/<name>/tests/claude/*.json
                  - plugins/*/skills/<name>/tests/claude/*.json
  --dir <dir>     Run all cases in one directory (default mode)

Defaults:
  --dir $CASES_DIR_DEFAULT
  --output-dir $OUTPUT_DIR_DEFAULT
  --claude-bin claude (or env CLAUDE_BIN)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      CASE_FILE="${2:-}"
      shift 2
      ;;
    --skill)
      SKILL_NAME="${2:-}"
      shift 2
      ;;
    --dir)
      CASES_DIR="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --claude-bin)
      CLAUDE_BIN="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$CASE_FILE" && -n "$SKILL_NAME" ]]; then
  echo "Error: --case and --skill cannot be used together" >&2
  exit 1
fi

collect_cases_from_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    return
  fi

  while IFS= read -r case_file; do
    CASES+=("$case_file")
  done < <(find "$dir" -maxdepth 1 -type f -name '*.json' | sort)
}

if [[ -n "$CASE_FILE" ]]; then
  python3 "$HARNESS" case \
    --case-file "$CASE_FILE" \
    --claude-bin "$CLAUDE_BIN" \
    --output-dir "$OUTPUT_DIR"
  exit $?
fi

CASES=()

if [[ -n "$SKILL_NAME" ]]; then
  collect_cases_from_dir "$REPO_ROOT/skills/$SKILL_NAME/tests/claude"

  while IFS= read -r plugin_cases_dir; do
    collect_cases_from_dir "$plugin_cases_dir"
  done < <(find "$REPO_ROOT/plugins" -type d -path "*/skills/$SKILL_NAME/tests/claude" | sort)

  if [[ ${#CASES[@]} -eq 0 ]]; then
    echo "Error: No .json case files found for skill '$SKILL_NAME'" >&2
    echo "Checked:" >&2
    echo "  $REPO_ROOT/skills/$SKILL_NAME/tests/claude" >&2
    echo "  $REPO_ROOT/plugins/*/skills/$SKILL_NAME/tests/claude" >&2
    exit 1
  fi
else
  if [[ ! -d "$CASES_DIR" ]]; then
    echo "Error: Cases directory not found: $CASES_DIR" >&2
    exit 1
  fi

  collect_cases_from_dir "$CASES_DIR"

  if [[ ${#CASES[@]} -eq 0 ]]; then
    echo "Error: No .json case files found in $CASES_DIR" >&2
    echo "Hint: start from $CASES_DIR/example.simple.example.json" >&2
    exit 1
  fi
fi

UNIQUE_CASES=()
while IFS= read -r case_file; do
  [[ -n "$case_file" ]] && UNIQUE_CASES+=("$case_file")
done < <(
  python3 - "${CASES[@]}" <<'PY'
import os
import sys

seen = set()
for raw in sys.argv[1:]:
    real = os.path.realpath(raw)
    if real in seen:
        continue
    seen.add(real)
    print(raw)
PY
)
CASES=("${UNIQUE_CASES[@]}")

PASS_COUNT=0
FAIL_COUNT=0

for case_file in "${CASES[@]}"; do
  if python3 "$HARNESS" case \
    --case-file "$case_file" \
    --claude-bin "$CLAUDE_BIN" \
    --output-dir "$OUTPUT_DIR"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo ""
echo "Claude skill test summary: pass=$PASS_COUNT fail=$FAIL_COUNT total=${#CASES[@]}"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
