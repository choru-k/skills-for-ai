# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of AI-agent skills with Claude plugin packaging for multi-AI orchestration, context handoffs, session forking, and development guides. Skills follow the [Agent Skills](https://agentskills.io) open standard and are distributed via the Claude Code plugin marketplace while also exposing a shared `skills/` index for cross-harness use.

## Repository Structure

```
plugins/
  <plugin-name>/
    .claude-plugin/plugin.json    # Plugin metadata (name, version, description)
    skills/
      <skill-name>/
        SKILL.md                  # Main skill instructions (YAML frontmatter + markdown body)
        scripts/                  # Executable shell/python scripts
        references/               # Documentation loaded into context as needed
        examples/                 # Usage examples
        templates/                # XML/markdown templates (complete-prompt)
        assets/                   # Output files not loaded into context
skills/                           # Shared cross-harness skill index (phase-1 bridge)
.claude-plugin/marketplace.json   # Top-level marketplace registry listing all plugins
```

Each plugin is self-contained under `plugins/<name>/` with its own `plugin.json` and skill directory.

## Skills

| Skill | Type | Dependencies |
|-------|------|-------------|
| **call-ai** | Low-level building block | External CLIs: `codex`, `gemini`, `claude` |
| **complete-prompt** | Context generator | None |
| **cc-context-fork** | Session forker | `claude` CLI |
| **second-opinion** | Orchestrator | call-ai + complete-prompt |
| **cc-dev-skills** | Development guide | None (has Python helper scripts) |
| **cc-dev-agents** | Development guide | None |
| **cc-dev-hooks** | Development guide | None |

### Dependency Chain

`second-opinion` composes `complete-prompt` (for context generation with `--refs`) and `call-ai` (for parallel AI execution). The `call-ai` skill reads model definitions from `ai-registry.yaml` as its single source of truth.

## Key Files

- **`ai-registry.yaml`** (`plugins/call-ai/skills/call-ai/`): Single source of truth for all AI provider/model definitions. Update models here only. Parsed at runtime with a section-aware Python3 parser.
- **`marketplace.json`** (`.claude-plugin/`): Registry of all plugins with `source` paths pointing to plugin directories.
- **`plugin.json`** (per-plugin `.claude-plugin/`): Plugin metadata — name, version, description, author.

## SKILL.md Conventions

- **Frontmatter fields**: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`, `model`, `context`, `agent`, `hooks`
- **`description`** is the primary triggering mechanism — include trigger phrases and "when to use" guidance there, not in the body
- **String substitutions**: `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `${CLAUDE_SESSION_ID}`
- Skills share a 2% context window budget for descriptions
- Keep SKILL.md body under 500 lines; split into `references/` files when approaching this limit

## Shell Scripts

Scripts in `call-ai` use bash with:
- Zellij pane integration (auto-detected via `$ZELLIJ` env var, falls back to headless)
- Parallel execution via `scripts/run-parallel.sh` with PID-based liveness monitoring
- Retry logic with exponential backoff (3x, 10s/20s/40s + jitter)
- Response storage in `.responses/` with metrics sidecars

## Adding a New Plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with name, version, description
2. Create `plugins/<name>/skills/<name>/SKILL.md` with frontmatter and instructions
3. Add the plugin entry to `.claude-plugin/marketplace.json`
4. Add scripts, references, examples as needed following the directory convention

## Installation Methods

- **Marketplace**: `claude plugin marketplace add choru-k/skills-for-ai && claude plugin install <name>`
- **Manual**: Copy `plugins/<name>/skills/<name>/` to `~/.claude/skills/<name>/`
