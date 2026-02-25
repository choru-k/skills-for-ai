# skills-for-ai

Custom AI-agent skills with **both Claude and Pi distribution support** — multi-AI orchestration, context handoffs, session forking, and development guides.

## Skills

| Skill | Description |
|-------|-------------|
| **call-ai** | Run prompts against external AIs (Codex, Gemini, Claude) with parallel execution, retries, and Zellij pane streaming |
| **complete-prompt** | Generate structured XML context prompts for AI-to-AI handoffs (9 modes + `--refs`) |
| **cc-context-fork** | Fork the current session to Haiku, Sonnet, or Opus with full conversation context preserved |
| **second-opinion** | Get second opinions from external AIs on programming questions with parallel execution and synthesis |
| **front-compaction-claude** | Claude wrapper for manual front-only compaction with hard tail replay semantics |
| **front-compaction-pi** | Pi-facing manual front-only compaction workflow plus extension command |
| **skill-playbook** | Evaluate external ideas, validate claims, track lifecycle status, and maintain best-practice notes |
| **clarify** | Turn ambiguous requests into clean, actionable specifications with structured clarification |
| **cc-dev-skills** | Guide for creating effective Claude Code skills with SKILL.md templates and validation scripts |
| **cc-dev-agents** | Comprehensive guide for creating Claude Code subagents with frontmatter, permissions, and hooks |
| **cc-dev-hooks** | Comprehensive guide for creating Claude Code hooks with command, prompt, and agent hook types |

## Shared Skill Index

- `skills/` provides a cross-harness shared skill index (Agent Skills style).
- This is used by Pi via `~/.share-ai/skills` in your dotfiles setup.
- Shared index entries may be regular directories or symlinks to plugin-owned skill folders (for example `plugins/*/skills/*` or `plugins/*/pi/skills/*`).
- Plugin-backed symlinks are generated from `package.json#pi.skills` via `just skills-index-sync`.

## Distribution Metadata

- `.claude-plugin/marketplace.json` is **Claude-only** plugin marketplace metadata.
- `package.json#pi` is **Pi-only** package metadata (skills/extensions for `pi install`).

## Installation

### Claude Code (plugin marketplace)

```bash
# Add the marketplace
claude plugin marketplace add choru-k/skills-for-ai

# Install individual skills
claude plugin install call-ai
claude plugin install complete-prompt
claude plugin install context-fork   # provides /cc-context-fork
claude plugin install second-opinion
claude plugin install front-compaction-claude
claude plugin install skill-playbook
claude plugin install clarify
claude plugin install cc-dev-skills
claude plugin install cc-dev-agents
claude plugin install cc-dev-hooks
```

### Claude Code (manual copy)

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai

# Copy whichever skills you want
cp -r /tmp/skills-for-ai/plugins/call-ai/skills/call-ai ~/.claude/skills/call-ai
cp -r /tmp/skills-for-ai/plugins/complete-prompt/skills/complete-prompt ~/.claude/skills/complete-prompt
cp -r /tmp/skills-for-ai/plugins/context-fork/skills/context-fork ~/.claude/skills/cc-context-fork
cp -r /tmp/skills-for-ai/plugins/second-opinion/skills/second-opinion ~/.claude/skills/second-opinion
cp -r /tmp/skills-for-ai/plugins/front-compaction/skills/front-compaction-claude ~/.claude/skills/front-compaction-claude
cp -r /tmp/skills-for-ai/plugins/skill-playbook/skills/skill-playbook ~/.claude/skills/skill-playbook
cp -r /tmp/skills-for-ai/plugins/clarify/skills/clarify ~/.claude/skills/clarify
cp -r /tmp/skills-for-ai/plugins/cc-dev-skills/skills/cc-dev-skills ~/.claude/skills/cc-dev-skills
cp -r /tmp/skills-for-ai/plugins/cc-dev-agents/skills/cc-dev-agents ~/.claude/skills/cc-dev-agents
cp -r /tmp/skills-for-ai/plugins/cc-dev-hooks/skills/cc-dev-hooks ~/.claude/skills/cc-dev-hooks
```

### Pi (single package install)

```bash
# Install directly from git
pi install git:github.com/choru-k/skills-for-ai

# Or (after npm publish)
pi install npm:@choru-k/skills-for-ai

# Or install local checkout
pi install /absolute/path/to/skills-for-ai
```

Pi uses `package.json#pi` in this repo to discover:
- skills (shared skill set)
- extensions (currently `front-compaction-pi` command, with `/front-compaction` alias)

### Just shortcuts

```bash
# Install local checkout into Pi
just pi-install-local

# Preview package tarball contents
just pi-pack-dry-run

# Sync generated skills/ symlink index
just skills-index-sync

# CI-style drift check (no writes)
just skills-index-check
```

## Development Hook (Graph QA)

This repo includes a pre-commit hook that validates skill-graph metadata and wikilinks.

```bash
# one-time setup in this repo
git config core.hooksPath .githooks

# run manually anytime
bash skills/skill-playbook/scripts/graph-qa.sh
```

The hook runs automatically on commit once `core.hooksPath` is set.

CI also enforces this on GitHub Actions:
- `.github/workflows/graph-qa.yml` runs on PRs/pushes that touch `skills/**` or `plugins/**/skills/**`.

## Usage

### Claude Code

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
/front-compaction-claude 30
/skill-playbook list
/clarify "Build a better onboarding experience"
/cc-dev-skills
/cc-dev-agents
/cc-dev-hooks
```

### Pi

After `pi install ...`, Pi loads skills/extensions from `package.json#pi`.
Example:

```
/front-compaction-pi 30
# alias still supported:
/front-compaction 30
```

## Prerequisites

- **call-ai** requires CLI tools: `codex`, `gemini`, and/or `claude` (install whichever providers you want to use)
- **complete-prompt** has no external dependencies
- **cc-context-fork** requires `claude` CLI
- **second-opinion** requires `call-ai` + `complete-prompt` (install all three)
- **front-compaction-claude**, **front-compaction-pi**, **skill-playbook**, **clarify** have no external dependencies
- **cc-dev-skills**, **cc-dev-agents**, **cc-dev-hooks** have no external dependencies

## License

[MIT](LICENSE)

## Author

[choru-k](https://github.com/choru-k)
