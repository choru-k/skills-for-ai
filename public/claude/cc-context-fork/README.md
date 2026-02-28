# cc-context-fork

A Claude Code skill that forks the current session to a different model (Haiku, Sonnet, or Opus) with full conversation context preserved. Useful for delegating sub-tasks to a model better suited for the job.

## Usage

| Command | Model | Use Case |
|---------|-------|----------|
| `/cc-context-fork "prompt"` | Haiku (default) | Quick queries, summaries, cheap tasks |
| `/cc-context-fork sonnet "prompt"` | Sonnet | Balanced analysis, moderate complexity |
| `/cc-context-fork opus "prompt"` | Opus | Deep analysis, complex reasoning |

Add `--tools "Read,Bash"` to customize allowed tools (default: `Read,Grep,Glob`).

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install context-fork
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/public/claude/cc-context-fork ~/.claude/skills/cc-context-fork
```

## How It Works

1. Parses the model and prompt from arguments
2. Writes the prompt to a temp file in `.responses/`
3. Runs `claude --model <model> --print --continue <session-id>` with the prompt piped via stdin
4. Returns the forked session's response

The forked session inherits the full conversation context, so the target model can reference earlier discussion without re-explaining.

## Limitations

- **Context cost** — Re-processes full conversation at the target model's rate
- **Headless** — Runs with `--print`, cannot ask clarifying questions
- **Haiku limits** — May struggle with complex multi-step reasoning

## License

[MIT](LICENSE)
