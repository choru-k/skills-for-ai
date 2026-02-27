#!/bin/bash
# Hook Linter
# Checks hook scripts for common issues and best practices
# Supports command, prompt, and agent hook patterns

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <hook-script.sh> [hook-script2.sh ...]"
  echo ""
  echo "Checks hook scripts for:"
  echo "  - Shebang presence"
  echo "  - set -euo pipefail usage"
  echo "  - Input reading from stdin"
  echo "  - Proper error handling"
  echo "  - Variable quoting"
  echo "  - Exit code usage"
  echo "  - Hardcoded paths"
  echo "  - Timeout considerations"
  echo "  - Deprecated output formats"
  echo "  - Deprecated placeholder usage"
  echo "  - Agent hook awareness"
  exit 1
fi

check_script() {
  local script="$1"
  local warnings=0
  local errors=0

  echo "🔍 Linting: $script"
  echo ""

  if [ ! -f "$script" ]; then
    echo "❌ Error: File not found"
    return 1
  fi

  # Check 1: Executable
  if [ ! -x "$script" ]; then
    echo "⚠️  Not executable (chmod +x $script)"
    ((warnings++))
  fi

  # Check 2: Shebang
  first_line=$(head -1 "$script")
  if [[ ! "$first_line" =~ ^#!/ ]]; then
    echo "❌ Missing shebang (#!/bin/bash)"
    ((errors++))
  fi

  # Check 3: set -euo pipefail
  if ! grep -q "set -euo pipefail" "$script"; then
    echo "⚠️  Missing 'set -euo pipefail' (recommended for safety)"
    ((warnings++))
  fi

  # Check 4: Reads from stdin
  if ! grep -q "cat\|read" "$script"; then
    echo "⚠️  Doesn't appear to read input from stdin"
    ((warnings++))
  fi

  # Check 5: Uses jq for JSON parsing
  if grep -q "tool_input\|tool_name\|hook_event_name" "$script" && ! grep -q "jq" "$script"; then
    echo "⚠️  Parses hook input but doesn't use jq"
    ((warnings++))
  fi

  # Check 6: Unquoted variables
  if grep -E '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$script" | grep -v '#' | grep -q .; then
    echo "⚠️  Potentially unquoted variables detected (injection risk)"
    echo "   Always use double quotes: \"\$variable\" not \$variable"
    ((warnings++))
  fi

  # Check 7: Hardcoded paths
  if grep -E '^[^#]*/home/|^[^#]*/usr/|^[^#]*/opt/' "$script" | grep -q .; then
    echo "⚠️  Hardcoded absolute paths detected"
    echo "   Use \$CLAUDE_PROJECT_DIR or \$CLAUDE_PLUGIN_ROOT"
    ((warnings++))
  fi

  # Check 8: Uses CLAUDE_PLUGIN_ROOT
  if ! grep -q "CLAUDE_PLUGIN_ROOT\|CLAUDE_PROJECT_DIR" "$script"; then
    echo "💡 Tip: Use \$CLAUDE_PLUGIN_ROOT for plugin-relative paths"
  fi

  # Check 9: Exit codes
  if ! grep -q "exit 0\|exit 2" "$script"; then
    echo "⚠️  No explicit exit codes (should exit 0 or 2)"
    ((warnings++))
  fi

  # Check 10: Deprecated PreToolUse output format
  if grep -q '"decision".*:.*"deny"\|"decision".*:.*"approve"\|"decision".*:.*"block"' "$script"; then
    if ! grep -q "hookSpecificOutput\|hook_event_name.*Stop\|hook_event_name.*SubagentStop\|PostToolUse" "$script"; then
      echo "⚠️  Uses deprecated top-level 'decision' format for PreToolUse"
      echo "   Migrate to hookSpecificOutput.permissionDecision (allow/deny/ask)"
      ((warnings++))
    fi
  fi

  # Check 11: Correct hookSpecificOutput usage
  if grep -q "hookSpecificOutput" "$script"; then
    if ! grep -q "hookEventName" "$script"; then
      echo "⚠️  hookSpecificOutput found but missing hookEventName field"
      ((warnings++))
    else
      echo "✅ Uses modern hookSpecificOutput format with hookEventName"
    fi
  fi

  # Check 12: Deprecated placeholders
  if grep -q '\$TOOL_INPUT\|\$TOOL_RESULT\|\$USER_PROMPT' "$script"; then
    echo "⚠️  Uses deprecated placeholder (\$TOOL_INPUT/\$TOOL_RESULT/\$USER_PROMPT)"
    echo "   For prompt hooks, use \$ARGUMENTS instead"
    ((warnings++))
  fi

  # Check 13: Long-running commands
  if grep -E 'sleep [0-9]{3,}|while true' "$script" | grep -v '#' | grep -q .; then
    echo "⚠️  Potentially long-running code detected"
    echo "   Default hook timeout: 600s (command), 60s (agent), 30s (prompt)"
    ((warnings++))
  fi

  # Check 14: Error messages to stderr
  if grep -q 'echo.*".*error\|Error\|denied\|Denied' "$script"; then
    if ! grep -q '>&2' "$script"; then
      echo "⚠️  Error messages should be written to stderr (>&2)"
      ((warnings++))
    fi
  fi

  # Check 15: Input validation
  if ! grep -q "if.*empty\|if.*null\|if.*-z" "$script"; then
    echo "💡 Tip: Consider validating input fields aren't empty"
  fi

  # Check 16: stop_hook_active check for Stop/SubagentStop hooks
  if grep -q "Stop\|stop" "$script"; then
    if ! grep -q "stop_hook_active" "$script"; then
      echo "💡 Tip: If this is a Stop/SubagentStop hook, check stop_hook_active to prevent infinite loops"
    fi
  fi

  # Check 17: Permission mode awareness
  if grep -q "permission_mode" "$script"; then
    echo "✅ Checks permission_mode — valid values: default, plan, acceptEdits, dontAsk, bypassPermissions"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "✅ No issues found"
    return 0
  elif [ $errors -eq 0 ]; then
    echo "⚠️  Found $warnings warning(s)"
    return 0
  else
    echo "❌ Found $errors error(s) and $warnings warning(s)"
    return 1
  fi
}

echo "🔎 Hook Script Linter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

total_errors=0

for script in "$@"; do
  if ! check_script "$script"; then
    ((total_errors++))
  fi
  echo ""
done

if [ $total_errors -eq 0 ]; then
  echo "✅ All scripts passed linting"
  exit 0
else
  echo "❌ $total_errors script(s) had errors"
  exit 1
fi
