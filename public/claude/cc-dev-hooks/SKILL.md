---
name: cc-dev-hooks
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse/PostToolUse/Stop hook", "validate tool use", "implement prompt-based hooks", "use ${CLAUDE_PLUGIN_ROOT}", "set up event-driven automation", "block dangerous commands", or mentions hook events (PreToolUse, PostToolUse, PermissionRequest, PostToolUseFailure, Stop, SubagentStop, SubagentStart, TeammateIdle, TaskCompleted, SessionStart, SessionEnd, UserPromptSubmit, PreCompact, Notification). Provides comprehensive guidance for creating and implementing Claude Code hooks with command, prompt, and agent hook types.
version: 0.2.0
---

# Hook Development for Claude Code

## Overview

Hooks are event-driven automation that execute at specific points in Claude Code's lifecycle. They let you validate operations, enforce policies, add context, and integrate external tools.

**Key capabilities:**
- Validate tool calls before execution (PreToolUse) or block permissions (PermissionRequest)
- React to tool results or failures (PostToolUse, PostToolUseFailure)
- Enforce completion standards (Stop, SubagentStop, TeammateIdle, TaskCompleted)
- Load project context and set environment variables (SessionStart)
- Inject context into subagents (SubagentStart) or before compaction (PreCompact)

## Hook Types

### Command Hooks (`type: "command"`)

Execute shell commands. Your script receives JSON on stdin and communicates via exit codes and stdout.

```json
{
  "type": "command",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
  "timeout": 30
}
```

**Use for:** Fast deterministic checks, file system ops, external tool integrations.

### Prompt Hooks (`type: "prompt"`)

Send a prompt to a Claude model (Haiku by default) for single-turn evaluation.

```json
{
  "type": "prompt",
  "prompt": "Evaluate if this tool use is safe: $ARGUMENTS",
  "timeout": 30
}
```

**Supported events:** PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCompleted. NOT TeammateIdle.

**Response:** The model returns `{"ok": true}` or `{"ok": false, "reason": "explanation"}`.

### Agent Hooks (`type: "agent"`)

Spawn a subagent with multi-turn tool access (Read, Grep, Glob) to verify conditions.

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass. Run the test suite. $ARGUMENTS",
  "timeout": 120
}
```

Same events as prompt hooks. Up to 50 turns. Default timeout: 60s. Same `ok`/`reason` response format.

> For detailed agent and async hook patterns, see `references/advanced.md`.

## Configuration Format

### Settings Format (All Locations)

All settings files use the `{"hooks": {...}}` wrapper:

```json
{
  "hooks": {
    "PreToolUse": [...],
    "Stop": [...],
    "SessionStart": [...]
  }
}
```

**Settings file locations:**

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes (commit to repo) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization-wide | Yes (admin-controlled) |

### Plugin hooks.json Format

Plugin hooks in `hooks/hooks.json` use the same wrapper with optional `description`:

```json
{
  "description": "Validation hooks for code quality",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate.sh"
          }
        ]
      }
    ]
  }
}
```

### Hooks in Skill/Agent Frontmatter

Hooks can be defined in YAML frontmatter, scoped to the component's lifecycle:

```yaml
---
name: secure-operations
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

For subagents, `Stop` hooks are automatically converted to `SubagentStop`.

### Disabling Hooks

Set `"disableAllHooks": true` in settings to temporarily disable all hooks. Use the `/hooks` menu toggle for interactive control.

## Hook Events (All 14)

| Event | When | Matcher Filters | Can Block? |
|-------|------|----------------|------------|
| SessionStart | Session begins/resumes | Session source: `startup`, `resume`, `clear`, `compact` | No |
| UserPromptSubmit | User submits prompt | No matcher (always fires) | Yes |
| PreToolUse | Before tool executes | Tool name: `Bash`, `Write`, `Edit`, `Read`, `mcp__.*` | Yes |
| PermissionRequest | Permission dialog shown | Tool name (same as PreToolUse) | Yes |
| PostToolUse | After tool succeeds | Tool name | No |
| PostToolUseFailure | After tool fails | Tool name | No |
| Notification | Notification sent | Type: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` | No |
| SubagentStart | Subagent spawned | Agent type: `Bash`, `Explore`, `Plan`, custom names | No |
| SubagentStop | Subagent finishes | Agent type (same as SubagentStart) | Yes |
| Stop | Main agent finishes | No matcher (always fires) | Yes |
| TeammateIdle | Teammate about to idle | No matcher (always fires) | Yes |
| TaskCompleted | Task marked complete | No matcher (always fires) | Yes |
| PreCompact | Before compaction | Trigger: `manual`, `auto` | No |
| SessionEnd | Session terminates | Reason: `clear`, `logout`, `prompt_input_exit`, `other` | No |

> For detailed per-event input/output schemas, see `references/events.md`.

## Matcher Patterns

Matchers are regex strings. Use `"*"`, `""`, or omit to match all occurrences.

**Tool name matching (PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest):**

```json
"matcher": "Write"                  // Exact tool
"matcher": "Read|Write|Edit"        // Multiple tools
"matcher": "mcp__.*"               // All MCP tools
"matcher": "mcp__github__.*"       // Specific MCP server
"matcher": "Notebook.*"            // Regex prefix match
```

**Events with no matcher support** (always fire): UserPromptSubmit, Stop, TeammateIdle, TaskCompleted.

## Hook Handler Fields

### Common Fields (All Types)

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | `"command"`, `"prompt"`, or `"agent"` |
| `timeout` | No | Seconds before canceling. Defaults: 600 (command), 30 (prompt), 60 (agent) |
| `statusMessage` | No | Custom spinner message while hook runs |
| `once` | No | If `true`, runs once per session then removed. Skills only |

### Command Hook Fields

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | Shell command to execute |
| `async` | No | If `true`, runs in background without blocking (command hooks only) |

### Prompt and Agent Hook Fields

| Field | Required | Description |
|-------|----------|-------------|
| `prompt` | Yes | Prompt text. Use `$ARGUMENTS` for hook input JSON placeholder |
| `model` | No | Model for evaluation. Defaults to a fast model |

## Hook Output

### Exit Codes (Command Hooks)

- **Exit 0** — Success. Stdout parsed for JSON output. For UserPromptSubmit/SessionStart, stdout becomes context for Claude.
- **Exit 2** — Blocking error. Stderr fed to Claude. Blocks action for events that support blocking.
- **Other** — Non-blocking error. Stderr shown in verbose mode only.

### JSON Output (Exit 0 Only)

Universal fields available to all events:

```json
{
  "continue": true,
  "stopReason": "Message to user when continue is false",
  "suppressOutput": false,
  "systemMessage": "Warning shown to user"
}
```

### Decision Control Summary

| Events | Pattern | Key Fields |
|--------|---------|------------|
| UserPromptSubmit, PostToolUse, PostToolUseFailure, Stop, SubagentStop | Top-level `decision` | `"decision": "block"`, `"reason": "..."` |
| TeammateIdle, TaskCompleted | Exit code only | Exit 2 blocks; stderr is feedback |
| PreToolUse | `hookSpecificOutput` | `permissionDecision` (allow/deny/ask), `permissionDecisionReason` |
| PermissionRequest | `hookSpecificOutput` | `decision.behavior` (allow/deny) |

### PreToolUse Output Example

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked"
  }
}
```

**Note:** Top-level `decision`/`reason` are **deprecated** for PreToolUse. Use `hookSpecificOutput.permissionDecision` instead.

### Stop/SubagentStop Output Example

```json
{
  "decision": "block",
  "reason": "Tests must pass before stopping"
}
```

### Prompt/Agent Hook Response

```json
{"ok": true}
{"ok": false, "reason": "Tests not passing — fix before proceeding"}
```

## Hook Input

All hooks receive JSON via stdin with these common fields:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/dir",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse"
}
```

**`permission_mode` values:** `"default"`, `"plan"`, `"acceptEdits"`, `"dontAsk"`, `"bypassPermissions"`

**Event-specific fields (common examples):**
- **PreToolUse/PostToolUse:** `tool_name`, `tool_input`, `tool_use_id`
- **PostToolUse:** adds `tool_response`
- **PostToolUseFailure:** adds `error`, `is_interrupt`
- **UserPromptSubmit:** `prompt`
- **Stop/SubagentStop:** `stop_hook_active` (check to prevent infinite loops)
- **SessionStart:** `source`, `model`
- **TaskCompleted:** `task_id`, `task_subject`, `task_description`
- **TeammateIdle:** `teammate_name`, `team_name`

In prompt/agent hooks, use `$ARGUMENTS` as the placeholder for input JSON. If `$ARGUMENTS` is absent, input is appended to the prompt.

> For complete per-event schemas with JSON examples, see `references/events.md`.

## Environment Variables

Available in all command hooks:

| Variable | Description |
|----------|-------------|
| `$CLAUDE_PROJECT_DIR` | Project root path |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin directory (portable paths) |
| `$CLAUDE_ENV_FILE` | SessionStart only: write `export` statements here to persist env vars |
| `$CLAUDE_CODE_REMOTE` | Set to `"true"` in remote web environments |

**Always use `${CLAUDE_PLUGIN_ROOT}` in plugin hook commands for portability.**

## Examples

### Command Hook: Block Destructive Commands (PreToolUse)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

Script outputs `hookSpecificOutput` with `permissionDecision`:

```bash
#!/bin/bash
COMMAND=$(jq -r '.tool_input.command')
if echo "$COMMAND" | grep -q 'rm -rf'; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Destructive command blocked"}}'
else
  exit 0
fi
```

### Prompt Hook: Verify Task Completion (Stop)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if all tasks are complete: $ARGUMENTS. Respond {\"ok\": true} or {\"ok\": false, \"reason\": \"what remains\"}."
          }
        ]
      }
    ]
  }
}
```

### Agent Hook: Verify Tests Pass (Stop)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Run the test suite and verify all tests pass. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

### Async Hook: Background Test Runner (PostToolUse)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-tests-async.sh",
            "async": true,
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

## Security Best Practices

1. **Validate inputs** — Always parse with `jq`, never trust raw input
2. **Quote variables** — Use `"$VAR"` not `$VAR` (injection risk)
3. **Block path traversal** — Check for `..` in file paths
4. **Use portable paths** — `${CLAUDE_PLUGIN_ROOT}` and `"$CLAUDE_PROJECT_DIR"`
5. **Set timeouts** — Prevent runaway hooks
6. **Check `stop_hook_active`** — Prevent infinite Stop hook loops

### Prevent Stop Hook Loops

```bash
#!/bin/bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0  # Allow stop, prevent infinite loop
fi
# ... your validation logic ...
```

## Hook Lifecycle Notes

- Hooks are **snapshotted at startup** — changes require session restart or `/hooks` review
- All matching hooks run **in parallel** — design for independence
- Identical handlers are **deduplicated** automatically
- Use `/hooks` command to view loaded hooks in current session
- Use `claude --debug` for detailed hook execution logs
- Toggle verbose mode with `Ctrl+O` to see hook output in transcript

## Quick Reference

### Best Practices

**DO:** Use `${CLAUDE_PLUGIN_ROOT}` for portability, validate inputs with `jq`, quote variables, set timeouts, check `stop_hook_active`, return structured JSON, test with sample input.

**DON'T:** Use hardcoded paths, trust input without validation, create long-running sync hooks (use `async` instead), rely on hook execution order, skip `stop_hook_active` checks in Stop hooks.

## Additional Resources

**Reference files:**
- `references/events.md` — Detailed per-event input/output schemas (all 14 events)
- `references/advanced.md` — Agent hooks, async hooks, frontmatter hooks, cross-event workflows
- `references/patterns.md` — Common hook patterns (10+ proven patterns)
- `references/migration.md` — Migrating from basic to advanced hooks

**Example scripts:** `examples/validate-write.sh`, `examples/validate-bash.sh`, `examples/load-context.sh`

**Utility scripts:** `scripts/validate-hook-schema.sh`, `scripts/test-hook.sh`, `scripts/hook-linter.sh`

**Official docs:** https://code.claude.com/docs/en/hooks (reference), https://code.claude.com/docs/en/hooks-guide (guide)
