# complete-prompt

A Claude Code skill for generating self-contained AI-to-AI context handoff prompts. Capture your current conversation context in structured XML and seamlessly continue work in a fresh session or hand off to another LLM.

## Modes

| Mode | Command | Use Case |
|------|---------|----------|
| **Full** | `/cp` | Default. Complete context for implementation |
| **Brief** | `/cp brief` | Quick questions, minimal context |
| **Debug** | `/cp debug` | Troubleshooting errors, fresh diagnosis |
| **Architect** | `/cp architect` | Design discussion, no implementation |
| **Diff** | `/cp diff` | Code review, comparing changes |
| **General** | `/cp general` | Non-technical catch-all |
| **Research** | `/cp research` | Literature review, fact-finding |
| **Career** | `/cp career` | Resume, job search, interview prep |
| **Learning** | `/cp learning` | Study plans, tutoring, skill acquisition |

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
cp -r /tmp/skills-for-ai/plugins/complete-prompt/skills/complete-prompt ~/.claude/skills/complete-prompt
```

Claude Code discovers skills in `~/.claude/skills/` automatically.

## How It Works

1. **Invoke** — Type `/cp [mode]` in Claude Code (e.g., `/cp debug`)
2. **Review** — The agent analyzes your full conversation history, extracting project context, files, decisions, and status
3. **Template** — Loads the matching XML template from `templates/`
4. **Fill** — Populates every section automatically (you never fill templates manually)
5. **Save** — Writes the handoff XML to `.prompts/` and provides a clipboard command

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

Inline examples for general, research, career, and learning modes are in `SKILL.md`.

## License

[MIT](LICENSE)
