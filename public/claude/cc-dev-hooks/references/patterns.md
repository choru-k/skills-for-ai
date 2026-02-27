# Common Hook Patterns

This reference provides common, proven patterns for implementing Claude Code hooks. Use these patterns as starting points for typical hook use cases.

## Pattern 1: Security Validation (PreToolUse)

Block dangerous file writes using command hooks with correct `hookSpecificOutput`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-write.sh"
          }
        ]
      }
    ]
  }
}
```

**Script outputs:**
```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$file_path" == *".."* ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Path traversal detected"}}'
  exit 0
fi

if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Cannot write to system directory"}}'
  exit 0
fi

exit 0
```

**Use for:** Preventing writes to sensitive files or system directories.

## Pattern 2: Test Enforcement (Stop)

Ensure tests run before stopping. Uses `decision: "block"` with `reason`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Review the conversation. If code was modified (Write/Edit tools used), verify tests were executed. Respond with {\"ok\": true} if tests were run, or {\"ok\": false, \"reason\": \"Tests must be run after code changes\"} if not. Context: $ARGUMENTS"
          }
        ]
      }
    ]
  }
}
```

**Use for:** Enforcing quality standards and preventing incomplete work.

## Pattern 3: Context Loading (SessionStart)

Load project-specific context at session start:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/load-context.sh"
          }
        ]
      }
    ]
  }
}
```

**Example script (load-context.sh):**
```bash
#!/bin/bash
cd "$CLAUDE_PROJECT_DIR" || exit 1

if [ -f "package.json" ]; then
  echo "Node.js project detected"
  echo "export PROJECT_TYPE=nodejs" >> "$CLAUDE_ENV_FILE"
elif [ -f "Cargo.toml" ]; then
  echo "Rust project detected"
  echo "export PROJECT_TYPE=rust" >> "$CLAUDE_ENV_FILE"
fi
```

**Use for:** Automatically detecting and configuring project-specific settings.

## Pattern 4: Notification Logging

Log all notifications for audit or analysis:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-notification.sh"
          }
        ]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/idle-alert.sh"
          }
        ]
      }
    ]
  }
}
```

**Use for:** Tracking notifications or integration with external logging/alerting.

## Pattern 5: MCP Tool Monitoring (PreToolUse)

Monitor and validate MCP tool usage:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__.*__delete.*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Deletion operation detected. Verify: Is this deletion intentional? Can it be undone? Are there backups? Respond {\"ok\": true} if safe or {\"ok\": false, \"reason\": \"...\"} if not. Context: $ARGUMENTS"
          }
        ]
      }
    ]
  }
}
```

**Use for:** Protecting against destructive MCP operations.

## Pattern 6: Build Verification (Stop)

Ensure project builds after code changes:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Check if code was modified during this session. If Write/Edit tools were used, run the build command and verify it succeeds. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

**Use for:** Catching build errors before committing.

## Pattern 7: Permission Confirmation (PreToolUse)

Escalate dangerous operations to the user:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-destructive.sh"
          }
        ]
      }
    ]
  }
}
```

**Script:**
```bash
#!/bin/bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$command" | grep -qE '(rm|delete|drop|truncate)'; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: "Destructive command detected — confirm with user"}}'
else
  exit 0
fi
```

**Use for:** User confirmation on potentially destructive commands.

## Pattern 8: Code Quality Checks (PostToolUse)

Run linters after file edits:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-quality.sh"
          }
        ]
      }
    ]
  }
}
```

**Script:**
```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

if [[ "$file_path" == *.js ]] || [[ "$file_path" == *.ts ]]; then
  lint_output=$(npx eslint "$file_path" 2>&1)
  if [ $? -ne 0 ]; then
    echo "{\"decision\": \"block\", \"reason\": \"Lint errors: $lint_output\"}"
    exit 0
  fi
fi

exit 0
```

**Use for:** Automatic code quality enforcement.

## Pattern 9: Temporarily Active Hooks

Create hooks that only run when explicitly enabled via flag files:

```bash
#!/bin/bash
FLAG_FILE="$CLAUDE_PROJECT_DIR/.enable-security-scan"

if [ ! -f "$FLAG_FILE" ]; then
  exit 0  # Quick exit when disabled
fi

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# Run security scan
security-scanner "$file_path"
```

**Activation:** `touch .enable-security-scan` / `rm .enable-security-scan`

**Use for:** Temporary debugging hooks, opt-in validation, feature flags.

## Pattern 10: Configuration-Driven Hooks

Use JSON configuration to control hook behavior:

```bash
#!/bin/bash
CONFIG_FILE="$CLAUDE_PROJECT_DIR/.claude/my-plugin.local.json"

if [ -f "$CONFIG_FILE" ]; then
  strict_mode=$(jq -r '.strictMode // false' "$CONFIG_FILE")
  max_file_size=$(jq -r '.maxFileSize // 1000000' "$CONFIG_FILE")
else
  strict_mode=false
  max_file_size=1000000
fi

if [ "$strict_mode" != "true" ]; then
  exit 0
fi

input=$(cat)
file_size=$(echo "$input" | jq -r '.tool_input.content | length')

if [ "$file_size" -gt "$max_file_size" ]; then
  jq -n --arg reason "File exceeds configured size limit ($max_file_size)" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
```

**Use for:** User-configurable hook behavior, per-project settings.

## Pattern 11: Failure Recovery (PostToolUseFailure)

React to tool failures with helpful context:

```json
{
  "hooks": {
    "PostToolUseFailure": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/failure-context.sh"
          }
        ]
      }
    ]
  }
}
```

**Script:**
```bash
#!/bin/bash
input=$(cat)
error=$(echo "$input" | jq -r '.error // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

context=""
if echo "$error" | grep -q "ENOENT"; then
  context="File not found error. Check if the file path exists and is spelled correctly."
elif echo "$error" | grep -q "EACCES"; then
  context="Permission denied. The file may need different permissions."
fi

if [ -n "$context" ]; then
  jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "PostToolUseFailure", additionalContext: $ctx}}'
fi

exit 0
```

**Use for:** Providing helpful context to Claude after tool failures.

## Pattern 12: Task Completion Gates (TaskCompleted)

Enforce quality before tasks can be marked complete:

```bash
#!/bin/bash
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject')

# Run tests
if ! npm test 2>&1; then
  echo "Tests must pass before completing: $TASK_SUBJECT" >&2
  exit 2
fi

# Run lint
if ! npm run lint 2>&1; then
  echo "Lint must pass before completing: $TASK_SUBJECT" >&2
  exit 2
fi

exit 0
```

**Use for:** Enforcing quality gates in agent team workflows.

## Pattern Combinations

Combine multiple patterns for comprehensive protection:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-write.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Validate bash command safety: destructive ops, privilege escalation, network access. $ARGUMENTS"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-quality.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Verify tests were run and build succeeded. $ARGUMENTS"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/load-context.sh"
          }
        ]
      }
    ]
  }
}
```
