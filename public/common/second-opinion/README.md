# second-opinion

A skill for Claude Code, Pi Agent, and OpenCode that gets second opinions from external AIs (Codex, Gemini, Claude) on programming questions. Composes the `call-ai` and `complete-prompt` skills to build context, dispatch queries in parallel, and synthesize responses.

Frontmatter may include Claude-oriented metadata (`user-invocable`, `allowed-tools`) for compatibility. Pi/OpenCode ignore these extra fields safely.

## Command Mapping

| Harness | Command |
|---------|---------|
| Claude Code | `/so [ai-spec] "question"` |
| Pi Agent | `/skill:second-opinion [ai-spec] "question"` |
| OpenCode | Load via `skill` tool (or add a custom `/so` command wrapper) |

`ai-spec` values (optional; default is Codex+Gemini):
- singles: `codex`, `gemini`, `claude`
- pairs: `codex+gemini` (`:cg`), `codex+claude` (`:cc`), `gemini+claude` (`:gc`)
- triad: `:trio`
- full matrix: `:all`

## Quick Reference

| AI Spec | AIs Called | Responses |
|---------|------------|-----------|
| *(none)* | Codex + Gemini thorough | 2 |
| `codex+gemini` / `:cg` | Codex + Gemini thorough | 2 |
| `codex+claude` / `:cc` | Codex + Claude thorough | 2 |
| `gemini+claude` / `:gc` | Gemini + Claude thorough | 2 |
| `:trio` | Codex + Gemini + Claude thorough | 3 |
| `:all` | All 3 AIs × both variants | 6 |
| `codex` | Codex thorough only | 1 |
| `gemini` | Gemini thorough only | 1 |
| `claude` | Claude thorough only | 1 |

## Prerequisites

This skill requires two sibling skills to be installed:

- **[call-ai](https://github.com/choru-k/skills-for-ai)** — Low-level AI calling (provides `run-parallel.sh` and `ai-registry.yaml`)
- **[complete-prompt](https://github.com/choru-k/skills-for-ai)** — Context prompt generation (provides XML prompt builder)

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install second-opinion
claude plugin install call-ai          # required dependency
claude plugin install complete-prompt  # required dependency
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/public/common/second-opinion ~/.claude/skills/second-opinion
cp -r /tmp/skills-for-ai/public/common/call-ai ~/.claude/skills/call-ai
cp -r /tmp/skills-for-ai/public/common/complete-prompt ~/.claude/skills/complete-prompt
```

For Pi, expose these same skills through your Pi skill path (e.g., `~/.share-ai/skills` in this dotfiles setup), then invoke with `/skill:second-opinion ...`.

## How It Works

1. Uses a skill graph entrypoint (`graph/index.md`) for progressive disclosure
2. Parses AI spec and question from arguments
3. Evaluates whether external AIs can add value
4. Builds context via `/complete-prompt` with `--refs` (file paths, not full contents)
5. Uses a coordinator agent when available (harness subagent mechanism), otherwise runs `run-parallel.sh` directly
6. Verifies responses and synthesizes agreements/disagreements

## License

[MIT](LICENSE)
