# cc-dev-agents

A Claude Code skill that provides comprehensive guidance for creating subagents (Task tool agents). Covers frontmatter configuration, system prompts, tool selection, permission modes, memory/storage, hooks, and best practices.

## Usage

Invoke when creating or configuring subagents:

```
/cc-dev-agents
"Create a subagent for running tests"
"What permissionMode should I use?"
"How do I give a subagent access to memory?"
```

## What It Covers

- **Frontmatter fields** — name, description, tools, permissionMode, model selection
- **System prompt design** — role definition, constraints, output format
- **Triggering conditions** — when-to-use descriptions for automatic invocation
- **Tool allowlists** — which tools to grant for different use cases
- **Permission modes** — default, full, none, and custom configurations
- **Storage scopes** — project vs global memory, subagent-specific storage
- **Hooks** — SubagentStart, SubagentStop, and agent-specific automation
- **Examples** — Real-world subagent patterns with complete configurations

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install cc-dev-agents
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/public/claude/cc-dev-agents ~/.claude/skills/cc-dev-agents
```

## License

[MIT](LICENSE)
