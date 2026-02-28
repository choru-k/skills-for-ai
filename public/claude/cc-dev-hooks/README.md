# cc-dev-hooks

A Claude Code skill that provides comprehensive guidance for creating hooks — event-driven automations that run on tool calls, permission requests, session events, and more. Covers command, prompt, and agent hook types.

## Usage

Invoke when creating or configuring hooks:

```
/cc-dev-hooks
"Create a PreToolUse hook to block dangerous commands"
"Add a PostToolUse hook for auto-formatting"
"How do I use ${CLAUDE_PLUGIN_ROOT}?"
```

## What It Covers

- **Hook events** — PreToolUse, PostToolUse, PermissionRequest, PostToolUseFailure, Stop, SubagentStop, SubagentStart, TeammateIdle, TaskCompleted, SessionStart, SessionEnd, UserPromptSubmit, PreCompact, Notification
- **Hook types** — command (shell), prompt (LLM-based), agent (autonomous)
- **Matchers** — Tool name patterns, glob matching, event filtering
- **Environment variables** — `${CLAUDE_PLUGIN_ROOT}`, tool input/output access
- **Blocking vs non-blocking** — When hooks can prevent or modify actions
- **Examples** — Real-world hook patterns with complete configurations

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install cc-dev-hooks
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/public/claude/cc-dev-hooks ~/.claude/skills/cc-dev-hooks
```

## License

[MIT](LICENSE)
