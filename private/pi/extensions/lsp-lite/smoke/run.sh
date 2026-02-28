#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
RESULTS_DIR="${RESULTS_DIR:-$(mktemp -d /tmp/pi-lsp-lite-smoke-XXXX)}"

if ! command -v pi >/dev/null 2>&1; then
  echo "pi command not found in PATH" >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"
cd "$REPO_ROOT"

extract_lsp_text() {
  local jsonl_path="$1"
  python3 - "$jsonl_path" <<'PY'
import json
import sys

path = sys.argv[1]
text = ""

with open(path, "r", encoding="utf-8") as f:
    for line in f:
        try:
            event = json.loads(line)
        except Exception:
            continue

        if event.get("type") != "message_start":
            continue

        message = event.get("message", {})
        if message.get("role") != "toolResult" or message.get("toolName") != "lsp":
            continue

        for chunk in message.get("content", []):
            if chunk.get("type") == "text":
                text = chunk.get("text", "")
                break

if text:
    print(text)
    raise SystemExit(0)

print(f"No lsp tool result found in {path}", file=sys.stderr)
raise SystemExit(1)
PY
}

failures=0

run_case() {
  local name="$1"
  local prompt="$2"
  shift 2

  local jsonl="$RESULTS_DIR/${name}.jsonl"
  pi --no-session --mode json "$prompt" > "$jsonl"

  local output
  output="$(extract_lsp_text "$jsonl")"

  echo
  echo "=== $name ==="
  printf '%s\n' "$output" | head -n 8

  local ok=1
  for expected in "$@"; do
    if [[ "$output" != *"$expected"* ]]; then
      echo "  missing: $expected"
      ok=0
    fi
  done

  if [[ "$ok" -eq 1 ]]; then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
}

run_case_any() {
  local name="$1"
  local prompt="$2"
  shift 2

  local jsonl="$RESULTS_DIR/${name}.jsonl"
  pi --no-session --mode json "$prompt" > "$jsonl"

  local output
  output="$(extract_lsp_text "$jsonl")"

  echo
  echo "=== $name ==="
  printf '%s\n' "$output" | head -n 8

  local ok=0
  for expected in "$@"; do
    if [[ "$output" == *"$expected"* ]]; then
      ok=1
      break
    fi
  done

  if [[ "$ok" -eq 1 ]]; then
    echo "  PASS"
  else
    echo "  missing all of: $*"
    echo "  FAIL"
    failures=$((failures + 1))
  fi
}

run_ts_rename_apply_case() {
  local name="ts_rename_apply"
  local tmpd
  tmpd="$(mktemp -d /tmp/pi-lsp-ts-rename-XXXX)"
  cp "$FIXTURES_DIR/ts/tsconfig.json" "$tmpd/tsconfig.json"
  cp "$FIXTURES_DIR/ts/intel.ts" "$tmpd/intel.ts"

  local jsonl="$RESULTS_DIR/${name}.jsonl"
  pi --no-session --mode json "Use lsp action=rename file=$tmpd/intel.ts line=5 column=7 new_name=renamedValue apply=true" > "$jsonl"

  local output
  output="$(extract_lsp_text "$jsonl")"

  echo
  echo "=== $name ==="
  printf '%s\n' "$output" | head -n 8

  local ok=1
  if [[ "$output" != *"Applied rename edits"* ]]; then
    echo "  missing: Applied rename edits"
    ok=0
  fi

  if ! rg -q "renamedValue" "$tmpd/intel.ts"; then
    echo "  missing: renamedValue in applied file"
    ok=0
  fi

  rm -rf "$tmpd"

  if [[ "$ok" -eq 1 ]]; then
    echo "  PASS"
  else
    echo "  FAIL"
    failures=$((failures + 1))
  fi
}

run_case status \
  "Use lsp action=status" \
  "lsp-lite status" \
  "gopls:" \
  "pyright:" \
  "terraform:"

run_case go_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/go/main.go" \
  "cannot use \"a\""

run_case_any python_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/python/main.py" \
  "Type \"Literal['a']\" is not assignable" \
  "No diagnostics"

run_case bash_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/bash/main.sh" \
  "Couldn't find 'fi'"

run_case ts_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/ts/main.ts" \
  "TS2322"

run_case lua_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/lua/main.lua" \
  "undefined variable 'not_defined_global'"

run_case terraform_diagnostics \
  "Use lsp action=diagnostics file=$FIXTURES_DIR/terraform/main.tf" \
  "Reference to undeclared input variable"

run_case go_definition \
  "Use lsp action=definition file=$FIXTURES_DIR/go/intel.go line=6 column=10" \
  "defined here as func foo() int"

run_case go_references \
  "Use lsp action=references file=$FIXTURES_DIR/go/intel.go line=6 column=10" \
  "intel.go:3:6-9" \
  "intel.go:6:9-12"

run_case go_hover \
  "Use lsp action=hover file=$FIXTURES_DIR/go/intel.go line=6 column=10" \
  "foo() int"

run_case go_symbols \
  "Use lsp action=symbols file=$FIXTURES_DIR/go/intel.go" \
  "foo Function" \
  "use Function"

run_case go_rename_preview \
  "Use lsp action=rename file=$FIXTURES_DIR/go/intel.go line=6 column=10 new_name=bar" \
  "func bar() int" \
  "return bar()"

run_case_any python_definition \
  "Use lsp action=definition file=$FIXTURES_DIR/python/intel.py line=4 column=10" \
  "intel.py:" \
  "does not support definition"

run_case_any python_hover \
  "Use lsp action=hover file=$FIXTURES_DIR/python/intel.py line=4 column=10" \
  "add_one" \
  "does not support hover" \
  "No hover information"

run_case_any ts_references \
  "Use lsp action=references file=$FIXTURES_DIR/ts/intel.ts line=5 column=15" \
  "intel.ts:" \
  "does not support references"

run_case_any ts_symbols \
  "Use lsp action=symbols file=$FIXTURES_DIR/ts/intel.ts" \
  "addOne" \
  "does not support symbols"

run_case_any ts_rename_preview \
  "Use lsp action=rename file=$FIXTURES_DIR/ts/intel.ts line=5 column=7 new_name=renamedValue" \
  "renamedValue" \
  "does not support rename"

run_ts_rename_apply_case

run_case_any lua_symbols \
  "Use lsp action=symbols file=$FIXTURES_DIR/lua/intel.lua" \
  "add_one" \
  "does not support symbols"

run_case_any lua_hover \
  "Use lsp action=hover file=$FIXTURES_DIR/lua/intel.lua line=5 column=15" \
  "add_one" \
  "Workspace loading" \
  "does not support hover" \
  "No hover information"

run_case terraform_rename_unsupported \
  "Use lsp action=rename file=$FIXTURES_DIR/terraform/main.tf line=10 column=11 new_name=renamedOutput" \
  "renameProvider=false"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "All lsp-lite smoke tests passed."
else
  echo "lsp-lite smoke tests failed: $failures"
fi

echo "JSON logs: $RESULTS_DIR"

[[ "$failures" -eq 0 ]]
