# skills-for-ai

Custom AI-agent skills with Claude plugin support — multi-AI orchestration, context handoffs, session forking, and development guides.

## Skills

| Skill | Description |
|-------|-------------|
| **call-ai** | Run prompts against external AIs (Codex, Gemini, Claude) with parallel execution, retries, and Zellij pane streaming |
| **complete-prompt** | Generate structured XML context prompts for AI-to-AI handoffs (9 modes + `--refs`) |
| **cc-context-fork** | Fork the current session to Haiku, Sonnet, or Opus with full conversation context preserved |
| **second-opinion** | Get second opinions from external AIs on programming questions with parallel execution and synthesis |
| **cc-dev-skills** | Guide for creating effective Claude Code skills with SKILL.md templates and validation scripts |
| **cc-dev-agents** | Comprehensive guide for creating Claude Code subagents with frontmatter, permissions, and hooks |
| **cc-dev-hooks** | Comprehensive guide for creating Claude Code hooks with command, prompt, and agent hook types |

## Shared Skill Index

- `skills/` provides a cross-harness shared skill index (Agent Skills style).
- This is used by Pi via `~/.share-ai/skills` in your dotfiles setup.
- During phase-1 migration, some shared entries are bridge symlinks back to dotfiles skill sources.

## Installation

### Plugin marketplace

```bash
# Add the marketplace
claude plugin marketplace add choru-k/skills-for-ai

# Install individual skills
claude plugin install call-ai
claude plugin install complete-prompt
claude plugin install context-fork   # provides /cc-context-fork
claude plugin install second-opinion
claude plugin install cc-dev-skills
claude plugin install cc-dev-agents
claude plugin install cc-dev-hooks
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai

# Copy whichever skills you want
cp -r /tmp/skills-for-ai/plugins/call-ai/skills/call-ai ~/.claude/skills/call-ai
cp -r /tmp/skills-for-ai/plugins/complete-prompt/skills/complete-prompt ~/.claude/skills/complete-prompt
cp -r /tmp/skills-for-ai/plugins/context-fork/skills/context-fork ~/.claude/skills/cc-context-fork
cp -r /tmp/skills-for-ai/plugins/second-opinion/skills/second-opinion ~/.claude/skills/second-opinion
cp -r /tmp/skills-for-ai/plugins/cc-dev-skills/skills/cc-dev-skills ~/.claude/skills/cc-dev-skills
cp -r /tmp/skills-for-ai/plugins/cc-dev-agents/skills/cc-dev-agents ~/.claude/skills/cc-dev-agents
cp -r /tmp/skills-for-ai/plugins/cc-dev-hooks/skills/cc-dev-hooks ~/.claude/skills/cc-dev-hooks
```

## Usage

After installation, skills appear as slash commands in Claude Code:

```
/call-ai "What are the tradeoffs of REST vs GraphQL?"
/call-ai :all "Review this architecture"
/cp debug
/cp brief --refs
/cc-context-fork haiku "summarize our conversation"
/cc-context-fork opus "deep analysis of this module"
/so "Redis or Memcached for session storage?"
/so :all "Review this architecture decision"
/cc-dev-skills
/cc-dev-agents
/cc-dev-hooks
```

## Prerequisites

- **call-ai** requires CLI tools: `codex`, `gemini`, and/or `claude` (install whichever providers you want to use)
- **complete-prompt** has no external dependencies
- **cc-context-fork** requires `claude` CLI
- **second-opinion** requires `call-ai` + `complete-prompt` (install all three)
- **cc-dev-skills**, **cc-dev-agents**, **cc-dev-hooks** have no external dependencies

## License

[MIT](LICENSE)

## Author

[choru-k](https://github.com/choru-k)
