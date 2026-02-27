---
name: cc-dev-agents
description: This skill should be used when the user asks to "create a subagent", "add a subagent", "write a subagent", "subagent frontmatter", "permissionMode", "subagent memory", "subagent hooks", "/agents command", "agent frontmatter", "when to use description", "agent examples", "agent tools", "autonomous agent", or needs guidance on subagent structure, system prompts, triggering conditions, storage scopes, or subagent development best practices for Claude Code.
version: 0.3.0
---

# Subagent Development for Claude Code

## Overview

Subagents are autonomous subprocesses that handle complex, multi-step tasks independently within Claude Code. They run as separate conversations with their own system prompts, tool access, and permission settings.

**Subagents vs agent teams:** A single subagent handles one focused task (code review, test generation). An *agent team* is a set of subagents orchestrated together — the main conversation launches multiple subagents, possibly in parallel, to divide work across specialized roles.

**Key concepts:**
- Subagents are markdown files with YAML frontmatter + a system prompt body
- Only `name` and `description` are required frontmatter fields
- Stored in 4 scopes with clear priority (CLI > project > user > plugin)
- Built-in subagents ship with Claude Code (Explore, Plan, etc.)
- The `/agents` command is the **recommended** way to create and manage subagents
- Subagents can run in foreground or background, be resumed, and have persistent memory
- **Subagents cannot spawn other subagents**

## Creating Subagents

### Method 1: `/agents` Command (Recommended)

Run `/agents` in Claude Code for an interactive interface:

1. Select **Create new agent** → choose **Project-level** or **User-level**
2. Select **Generate with Claude** and describe the subagent
3. Select tools (read-only, all, or custom)
4. Select model (sonnet, opus, haiku, or inherit)
5. Choose a background color for UI identification
6. Save — available immediately, no restart needed

### Method 2: Manual File Creation

Create a markdown file in the appropriate scope directory:

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze code and provide
specific, actionable feedback on quality, security, and best practices.
```

### Method 3: CLI `--agents` Flag

Pass subagent files or inline JSON for testing:

```bash
# File-based
claude --agents path/to/my-agent.md

# Inline JSON (useful for automation)
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer...",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'
```

The JSON format accepts the same fields as file frontmatter, plus `prompt` for the system prompt body.

### Method 4: AI-Assisted Generation

See `examples/agent-creation-prompt.md` for a complete template using the generation prompt from `references/agent-creation-system-prompt.md`.

## Subagent File Structure

```markdown
---
name: agent-identifier
description: Use this agent when [triggering conditions]. Examples:

<example>
Context: [Situation description]
user: "[User request]"
assistant: "[How assistant should respond and use this subagent]"
<commentary>
[Why this subagent should be triggered]
</commentary>
</example>

model: sonnet
tools: Read, Grep, Glob
permissionMode: acceptEdits
maxTurns: 25
---

You are [subagent role description]...

**Your Core Responsibilities:**
1. [Responsibility 1]
2. [Responsibility 2]

**Analysis Process:**
[Step-by-step workflow]

**Output Format:**
[What to return]
```

## Frontmatter Fields

### name (required)

Subagent identifier. Format: lowercase, numbers, hyphens only. 3-50 characters. Must start and end with alphanumeric.

**Good:** `code-reviewer`, `test-generator`, `api-docs-writer`
**Bad:** `helper` (generic), `-agent-` (hyphen start/end), `my_agent` (underscores)

### description (required)

Defines when Claude should trigger this subagent. **Most critical field.**

**Must include:**
1. Triggering conditions ("Use this agent when...")
2. Multiple `<example>` blocks showing usage (2-4 recommended)
3. Context, user request, and assistant response in each example
4. `<commentary>` explaining why subagent triggers

See `references/triggering-examples.md` for complete guide.

### model (optional)

**Options:** `inherit` (default), `sonnet`, `opus`, `haiku`

Omit unless the subagent needs a specific model. Use `haiku` for quick, high-volume tasks.

### tools (optional)

Restrict subagent to specific tools. Supports array or comma-separated string format:

```yaml
# Both formats are valid:
tools: Read, Grep, Glob, Bash
tools: ["Read", "Grep", "Glob", "Bash"]
```

**Default:** All tools inherited if omitted.

**Spawning restrictions:** When an agent runs as main thread with `claude --agent`, use `Task(agent_type)` to restrict which subagents it can spawn:

```yaml
tools: Task(worker, researcher), Read, Bash  # Only worker and researcher
tools: Task, Read, Bash                       # Any subagent
```

Note: `Task(agent_type)` only applies to agents running as main thread. Subagents cannot spawn other subagents.

**Common tool sets:**
- Read-only analysis: `Read, Grep, Glob`
- Code generation: `Read, Write, Grep`
- Testing: `Read, Bash, Grep`
- Full access: Omit field entirely

### disallowedTools (optional)

Denylist of tools. Use one or the other (`tools` vs `disallowedTools`), not both.

```yaml
disallowedTools: Write, Edit
```

### permissionMode (optional)

| Mode | Description |
|------|-------------|
| `default` | Inherits parent's permission mode |
| `acceptEdits` | Auto-approves file edits, prompts for Bash |
| `delegate` | Auto-approves edits + Bash, prompts for others |
| `dontAsk` | Auto-deny permission prompts (explicitly allowed tools still work) |
| `bypassPermissions` | Skip all permission checks (use with caution) |
| `plan` | Read-only — can explore but not modify |

If the parent uses `bypassPermissions`, this takes precedence and cannot be overridden.

**Recommendation:** `plan` for analysis-only, `acceptEdits` for code generation, `delegate` for full automation.

### maxTurns (optional)

Maximum agentic turns (API round-trips) before stopping. Set lower for simple tasks (5-10), higher for complex work (50+). Always set for subagents with elevated permissions.

### skills (optional)

Preload specific skills into the subagent's context. Full skill content is injected at startup — subagents don't inherit skills from the parent conversation.

```yaml
skills: ["api-conventions", "error-handling-patterns"]
```

### mcpServers (optional)

MCP servers available to this subagent. Each entry is a server name or inline definition.

```yaml
mcpServers: ["context7", "serena"]
```

**Note:** MCP tools are **not available** in background subagents.

### hooks (optional)

Lifecycle hooks scoped to this subagent. Uses nested format with `type: command`:

**Supported events in frontmatter:** `PreToolUse`, `PostToolUse`, `Stop`

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-command.sh"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
  Stop:
    - hooks:
        - type: command
          command: "echo 'Subagent finished'"
```

`Stop` hooks in frontmatter are automatically converted to `SubagentStop` events at runtime.

**Project-level hooks** (in `settings.json`) respond to subagent lifecycle:

| Event | Matcher input | When it fires |
|-------|---------------|---------------|
| `SubagentStart` | Agent type name | When a subagent begins execution |
| `SubagentStop` | Agent type name | When a subagent completes |

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/setup-db.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          { "type": "command", "command": "./scripts/cleanup.sh" }
        ]
      }
    ]
  }
}
```

### memory (optional)

Enable persistent memory that survives across sessions.

| Scope | Location | Use when |
|-------|----------|----------|
| `user` (recommended default) | `~/.claude/agent-memory/<name>/` | Learnings across all projects |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via VCS |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not version-controlled |

**Behavior when enabled:**
- System prompt automatically includes first 200 lines of `MEMORY.md`
- Instructions to curate `MEMORY.md` if it exceeds 200 lines
- Read, Write, and Edit tools are **automatically enabled**
- Include memory instructions in your system prompt for best results

```markdown
**Memory:**
Update your agent memory as you discover patterns, conventions, and
architectural decisions. Check memory at the start of each run.
```

### color (optional)

Background color for UI identification in the Claude Code interface. Set via `/agents` interactive setup.

## Storage Locations & Priority

| Priority | Location | Scope | Use Case |
|----------|----------|-------|----------|
| 1 (highest) | `--agents` CLI flag | Session | One-off or testing |
| 2 | `.claude/agents/` | Project | Team-shared, version-controlled |
| 3 | `~/.claude/agents/` | User | Personal subagents across projects |
| 4 (lowest) | Plugin `agents/` dir | Plugin | Distributed with a plugin |

## Built-in Subagents

| Subagent | Purpose | Model |
|----------|---------|-------|
| **Explore** | Fast codebase exploration (read-only) | Haiku |
| **Plan** | Research for plan mode (read-only) | Inherited |
| **general-purpose** | Complex multi-step tasks | Inherited |
| **Bash** | Command execution | Inherited |
| **statusline-setup** | Configure status line | Sonnet |
| **claude-code-guide** | Claude Code feature Q&A | Haiku |

Use `/agents` to see all available subagents (built-in + custom).

## Runtime Behavior

### Foreground vs Background

- **Foreground** (default): Main conversation waits. Permission prompts and clarifying questions pass through.
- **Background**: Runs concurrently. Permissions are pre-approved upfront before launch. `AskUserQuestion` fails silently (subagent continues). **MCP tools are not available** in background.

Press **Ctrl+B** during foreground execution to move to background. Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to disable background tasks entirely.

### Resumption

Subagents return an **agent ID** on completion. Resume with full context preserved by asking Claude to continue previous work. Transcripts persist at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.

### Auto-Compaction

Subagents compact at ~95% capacity. Override with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (e.g., `50`). Transcripts persist independently of main conversation compaction and are cleaned up based on `cleanupPeriodDays` (default: 30 days).

## System Prompt Design

The markdown body becomes the subagent's system prompt. Write in second person.

**Standard template:**
```markdown
You are [specific role] specializing in [domain].

**Your Core Responsibilities:**
1. [Primary responsibility]
2. [Secondary responsibility]

**Process:**
1. [Step one]
2. [Step two]

**Quality Standards:**
- [Standard 1]
- [Standard 2]

**Output Format:**
[What to include, how to structure]

**Edge Cases:**
- [Edge case 1]: [How to handle]
```

**DO:** Be specific, provide step-by-step process, define output format, include quality standards, address edge cases, keep under 10,000 characters.

**DON'T:** Write in first person, be vague, omit process steps, leave output format undefined, skip error cases.

See `references/system-prompt-design.md` for complete patterns.

## Architectural Patterns

### When to Use Subagents

**Use subagents:** Autonomous tasks, isolating high-volume output, parallel research, different permission levels, persistent memory for specialized domains.

**Use main conversation:** Tight back-and-forth, small tasks, full context needed.

**Use skills:** Injecting specialized knowledge into current conversation.

### Pattern: Parallel Research

Launch multiple subagents to search different areas simultaneously:
```
Research auth, database, and API modules in parallel using separate subagents
```

### Pattern: Chain of Specialists

Pipeline through a sequence: code-reviewer → fix-implementer → test-generator

### Pattern: Isolated Execution

Restricted tools for untrusted operations:
```yaml
name: sandbox-runner
tools: Read, Bash
permissionMode: plan
maxTurns: 10
```

## Restricting Subagents

Use `permissions.deny` in settings to prevent specific subagents:

```json
{ "permissions": { "deny": ["Task(dangerous-agent)"] } }
```

Or via CLI: `claude --disallowedTools "Task(agent-name)"`

## Additional Resources

- **`references/system-prompt-design.md`** — Complete system prompt patterns
- **`references/triggering-examples.md`** — Example formats and best practices
- **`references/agent-creation-system-prompt.md`** — The generation prompt from Claude Code
- **`examples/agent-creation-prompt.md`** — AI-assisted generation template
- **`examples/complete-agent-examples.md`** — Full subagent examples (6 use cases)
- **`scripts/validate-agent.sh`** — Validate subagent file structure
