---
name: context-fork
description: |
  Fork the current session and run a prompt with a different model.
  Full conversation context preserved. Use for "fork with haiku",
  "cheap query", "context fork", "delegate to haiku", "run with haiku",
  "fork with opus", or when you want a different model for a sub-task.
argument-hint: "[haiku|sonnet|opus] \"prompt\""
allowed-tools: Bash, Read, Write
---

# Context Fork

Fork the current session to a different model (Haiku by default) with full conversation context preserved. Useful for delegating sub-tasks to a model better suited for the job.

**Usage:**
- `/context-fork "summarize our conversation"` — Haiku (default)
- `/context-fork sonnet "review the architecture decisions"` — Sonnet
- `/context-fork opus "deep analysis of this module"` — Opus
- `/context-fork --tools "Read,Bash" "run tests and report"` — Custom tools

---

## Workflow

1. **Parse arguments** from `$ARGUMENTS` (see table below)
2. **Write prompt** to `$SKILL_DIR/.responses/fork-prompt-<timestamp>-$$.txt`
   - Resolve `SKILL_DIR` via: `${CLAUDE_SKILL_DIR}`, or the skill's directory
3. **Run the fork** via Bash:
   ```bash
   bash "$SKILL_DIR/scripts/context-fork.sh" \
     "${CLAUDE_SESSION_ID}" "<model>" "$PROMPT_FILE" [--tools "<tools>"]
   ```
4. **Read the response**: Script outputs `FILE: <path>` — read that file and present contents to user
5. **Clean up**: Remove the prompt temp file

## Argument Parsing

| Input | Model | Tools | Prompt |
|-------|-------|-------|--------|
| `"summarize this"` | haiku | Read,Grep,Glob | summarize this |
| `sonnet "explain the bug"` | sonnet | Read,Grep,Glob | explain the bug |
| `opus "deep analysis of module"` | opus | Read,Grep,Glob | deep analysis of module |
| `--tools "Read,Bash" "list files"` | haiku | Read,Bash | list files |
| `haiku --tools "Read" "check config"` | haiku | Read | check config |

First word `haiku`/`sonnet`/`opus` sets model (default: `haiku`). `--tools` overrides allowed tools (default: `Read,Grep,Glob`). Remainder is the prompt.

---

## Limitations

- **Context cost**: Forked session re-processes full conversation context at the target model's rate
- **Headless mode**: Runs with `-p` (print) — cannot ask clarifying questions. Prompts must be self-contained
- **Haiku limits**: May struggle with complex multi-step reasoning. Use `sonnet` or `opus` for harder tasks
- **`--continue` fallback**: If `${CLAUDE_SESSION_ID}` substitution fails, falls back to `--continue` (resumes most recent session in CWD)
