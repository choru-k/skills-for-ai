# second-opinion

A Claude Code skill that gets second opinions from external AIs (Codex, Gemini, Claude) on programming questions. Composes the `call-ai` and `complete-prompt` skills to build context, dispatch queries in parallel, and synthesize responses.

## Usage

| Command | AIs Called | Responses |
|---------|------------|-----------|
| `/so "question"` | Codex + Gemini | 2 |
| `/so :all "question"` | All 3 AIs × both variants | 6 |
| `/so codex "question"` | Codex only | 1 |
| `/so gemini "question"` | Gemini only | 1 |
| `/so claude "question"` | Claude (fresh context) | 1 |

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

## How It Works

1. Uses a skill graph entrypoint (`graph/index.md`) for progressive disclosure
2. Parses AI spec and question from arguments
3. Evaluates whether external AIs can add value
4. Builds context via `/complete-prompt` with `--refs` (file paths, not full contents)
5. Spawns a Sonnet coordinator sub-agent that calls external AIs in parallel
6. Verifies responses and synthesizes agreements/disagreements

## License

[MIT](LICENSE)
