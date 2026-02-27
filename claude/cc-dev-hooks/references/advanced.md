# Advanced Hook Techniques

This reference covers advanced hook patterns including agent hooks, async hooks, frontmatter hooks, and cross-event workflows.

## Agent-Based Hooks

Agent hooks (`type: "agent"`) spawn a subagent with multi-turn tool access to verify conditions before returning a decision. Unlike prompt hooks which make a single LLM call, agent hooks can read files, search code, and use other tools.

### How Agent Hooks Work

1. Claude Code spawns a subagent with your prompt and the hook's JSON input
2. The subagent can use tools like Read, Grep, and Glob to investigate
3. After up to **50 turns**, the subagent returns a structured decision
4. Claude Code processes the decision the same way as a prompt hook

### Configuration

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass. Run the test suite and check results. $ARGUMENTS",
  "model": "claude-sonnet-4-5-20250929",
  "timeout": 120
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"agent"` |
| `prompt` | Yes | What to verify. Use `$ARGUMENTS` for hook input JSON |
| `model` | No | Model to use. Defaults to a fast model |
| `timeout` | No | Seconds. Default: 60 |

### Response Format

Same as prompt hooks:

```json
{"ok": true}
{"ok": false, "reason": "Tests failing — 3 test suites have errors"}
```

### Supported Events

Same as prompt hooks: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCompleted.

**NOT supported:** TeammateIdle (exit code only).

### When to Use Agent vs Prompt Hooks

| Use Case | Hook Type |
|----------|-----------|
| Decision based on hook input data alone | Prompt |
| Need to inspect actual files or test output | Agent |
| Fast yes/no evaluation | Prompt |
| Multi-step verification (run tests, check output) | Agent |
| Simple policy check | Prompt |
| Complex condition requiring code inspection | Agent |

### Example: Verify Tests Before Stop

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Run npm test and verify all tests pass. Check for any failing or skipped tests. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

### Example: Verify Code Review Standards (PreToolUse)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "agent",
            "prompt": "Read the file being modified and verify: 1) No hardcoded secrets 2) Follows project coding standards 3) Has appropriate error handling. $ARGUMENTS",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

## Async Hooks (Background Execution)

Set `"async": true` on command hooks to run them in the background without blocking Claude.

### Configuration

```json
{
  "type": "command",
  "command": "/path/to/long-running-script.sh",
  "async": true,
  "timeout": 300
}
```

**Key points:**
- Only `type: "command"` hooks support `async`
- Hook starts immediately, Claude continues working
- When the script finishes, output is delivered on the next conversation turn
- Decision/blocking fields have no effect (action already proceeded)
- Each execution creates a separate background process (no deduplication)
- Default timeout: 600s (same as sync hooks)

### Example: Background Test Runner

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-tests-async.sh",
            "async": true,
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

**Script (run-tests-async.sh):**
```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run tests for source files
if [[ "$FILE_PATH" != *.ts && "$FILE_PATH" != *.js ]]; then
  exit 0
fi

RESULT=$(npm test 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "{\"systemMessage\": \"Tests passed after editing $FILE_PATH\"}"
else
  echo "{\"systemMessage\": \"Tests failed after editing $FILE_PATH: $RESULT\"}"
fi
```

### Example: Deploy Notification

```bash
#!/bin/bash
# Runs after any Bash command matching deployment patterns
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ "$COMMAND" == *"deploy"* ]] || [[ "$COMMAND" == *"push"* ]]; then
  curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"Deployment initiated: $COMMAND\"}" 2>/dev/null
fi

exit 0
```

### Limitations

- Cannot block or control behavior (action already proceeded)
- Output delivered on next conversation turn (may wait if session is idle)
- Prompt and agent hooks cannot be async
- No deduplication across multiple firings

## Hooks in Skill/Agent Frontmatter

Hooks can be scoped to a skill or agent's lifecycle via YAML frontmatter.

### Skill Frontmatter Hooks

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
  Stop:
    - hooks:
        - type: prompt
          prompt: "Verify all security checks passed: $ARGUMENTS"
---
```

- All hook events are supported
- Hooks are scoped to the skill's lifetime
- Cleaned up when the skill finishes
- `once: true` runs the hook only once per session

### Agent Frontmatter Hooks

Agents use the same format. `Stop` hooks in agent frontmatter are automatically converted to `SubagentStop` since that's the event that fires when a subagent completes.

```yaml
---
name: test-runner
description: Run tests with pre-validation
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate-test-command.sh"
---
```

## Multi-Stage Validation

Combine command and prompt hooks for layered validation:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/quick-check.sh",
            "timeout": 5
          },
          {
            "type": "prompt",
            "prompt": "Deep analysis of bash command safety: $ARGUMENTS",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Both hooks run in parallel. The command hook handles fast deterministic checks while the prompt hook handles complex reasoning.

## Conditional Hook Execution

Execute hooks based on environment or context:

```bash
#!/bin/bash
# Only run in CI environment
if [ -z "$CI" ]; then
  exit 0  # Skip in non-CI
fi

input=$(cat)
# ... validation code ...
```

**Use cases:**
- Different behavior in CI vs local
- Project-specific validation
- User-specific rules

## Cross-Event Workflows

Coordinate hooks across different events:

**SessionStart — Set up tracking:**
```bash
#!/bin/bash
echo "0" > /tmp/test-count-$$
echo "0" > /tmp/build-count-$$
```

**PostToolUse — Track events:**
```bash
#!/bin/bash
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [ "$tool_name" = "Bash" ]; then
  tool_result=$(echo "$input" | jq -r '.tool_response // empty')
  if [[ "$tool_result" == *"test"* ]]; then
    count=$(cat /tmp/test-count-$$ 2>/dev/null || echo "0")
    echo $((count + 1)) > /tmp/test-count-$$
  fi
fi
```

**Stop — Verify based on tracking:**
```bash
#!/bin/bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi

test_count=$(cat /tmp/test-count-$$ 2>/dev/null || echo "0")
if [ "$test_count" -eq 0 ]; then
  echo '{"decision": "block", "reason": "No tests were run during this session"}'
  exit 0
fi
```

## Performance Optimization

### Caching Validation Results

```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
cache_key=$(echo -n "$file_path" | md5sum | cut -d' ' -f1)
cache_file="/tmp/hook-cache-$cache_key"

# Check cache (5 minute TTL)
if [ -f "$cache_file" ]; then
  cache_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file")))
  if [ "$cache_age" -lt 300 ]; then
    cat "$cache_file"
    exit 0
  fi
fi

# Perform validation
result='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'

echo "$result" > "$cache_file"
echo "$result"
```

### Parallel Execution Design

All hooks within a matcher group run in parallel — design for independence:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {"type": "command", "command": "bash check-size.sh", "timeout": 2},
          {"type": "command", "command": "bash check-path.sh", "timeout": 2},
          {"type": "prompt", "prompt": "Check content safety: $ARGUMENTS", "timeout": 10}
        ]
      }
    ]
  }
}
```

All three run simultaneously, reducing total latency.

## Integration with External Systems

### Slack Notifications

```bash
#!/bin/bash
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

curl -X POST "$SLACK_WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d "{\"text\": \"Hook blocked ${tool_name} operation\"}" 2>/dev/null

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Blocked by policy"}}'
```

### Metrics Collection

```bash
#!/bin/bash
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

echo "hook.pretooluse.${tool_name}:1|c" | nc -u -w1 statsd.local 8125

exit 0
```

## Best Practices for Advanced Hooks

1. **Keep hooks independent** — Don't rely on execution order
2. **Use appropriate timeouts** — Command: 5-30s typical, Agent: 60-120s
3. **Handle errors gracefully** — Provide clear error messages
4. **Check `stop_hook_active`** — Prevent infinite loops in Stop/SubagentStop
5. **Use async for slow operations** — Don't block Claude unnecessarily
6. **Test thoroughly** — Cover edge cases and failure modes
7. **Monitor performance** — Track hook execution time with debug mode
8. **Provide escape hatches** — Flag files or config to disable hooks

## Common Pitfalls

### Assuming Hook Order
Hooks run in parallel — don't rely on one hook's output in another within the same event.

### Long-Running Sync Hooks
Use `"async": true` for hooks that take more than a few seconds.

### Missing `stop_hook_active` Check
Always check this in Stop/SubagentStop hooks to prevent infinite loops.

### Using Deprecated Output Format
Use `hookSpecificOutput.permissionDecision` for PreToolUse, not top-level `decision`.
