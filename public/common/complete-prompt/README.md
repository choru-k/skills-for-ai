# complete-prompt

A Claude Code skill for generating self-contained AI-to-AI context handoff prompts. Capture your current conversation context in structured XML and seamlessly continue work in a fresh session or hand off to another LLM.

## Command Mapping

| Harness | Command |
|---------|---------|
| Claude Code | `/cp [mode] [--refs]` (alias: `/complete-prompt [mode] [--refs]`) |
| Pi Agent | `/skill:complete-prompt [mode] [--refs]` |

## Modes

| Mode | Argument | Use Case |
|------|----------|----------|
| **Full** | *(default)* | Complete context for implementation |
| **Brief** | `brief` | Quick questions, minimal context |
| **Debug** | `debug` | Troubleshooting errors, fresh diagnosis |
| **Architect** | `architect` | Design discussion, no implementation |
| **Diff** | `diff` | Code review, comparing changes |
| **General** | `general` | Non-technical catch-all |
| **Research** | `research` | Literature review, fact-finding |
| **Career** | `career` | Resume, job search, interview prep |
| **Learning** | `learning` | Study plans, tutoring, skill acquisition |

Add `--refs` to any mode (e.g., `/cp debug --refs`) for token-efficient reference-only output when the receiving AI has codebase access.

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install complete-prompt
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/public/common/complete-prompt ~/.claude/skills/complete-prompt
```

Claude Code discovers skills in `~/.claude/skills/` automatically.

## How It Works

1. **Invoke** — Use `/cp [mode]` (or `/complete-prompt [mode]`) in Claude Code, or `/skill:complete-prompt [mode]` in Pi
2. **Route** — The skill graph entrypoint (`graph/index.md`) selects the minimal nodes needed
3. **Review** — The agent analyzes your conversation history, extracting project context, files, decisions, and status
4. **Template** — Loads the matching XML template from `templates/`
5. **Fill** — Populates every section automatically (you never fill templates manually)
6. **Save** — Writes the handoff XML to `.prompts/` and provides a clipboard command

## Output

Generated prompts are saved to `.prompts/` inside this skill's directory. This directory is gitignored — handoff files contain conversation context and are meant to be ephemeral.

```
.prompts/20260204-204532-debug.xml
.prompts/20260205-143000-research.xml
```

## Examples

See the `examples/` directory for sample outputs across modes:

- `examples/full.md` — 3 complete handoff examples
- `examples/brief.md` — 3 brief handoff examples
- `examples/debug.md` — 3 debug handoff examples
- `examples/architect.md` — 3 architect handoff examples
- `examples/diff.md` — 3 diff handoff examples
- `examples/refs.md` — reference-only (`--refs`) example
- `examples/general.md` — non-technical catch-all example
- `examples/research.md` — research/fact-finding example
- `examples/career.md` — career/job-search example
- `examples/learning.md` — learning/study-plan example

Mode-specific routing and generation rules are in the skill graph (`graph/`) and `templates/*.xml`.

## License

[MIT](LICENSE)
