---
name: call-ai
description: Run a prompt against external AIs (Codex, Gemini, Claude). Low-level building block for other skills. Use for "ask codex", "ask gemini", "call AI", or when delegating prompts to external models.
argument-hint: "[codex|gemini|claude|:all] \"prompt\""
user-invocable: true
---

# Call AI

Run prompts against external AI providers. This is a low-level building block skill.

**Alias:** `/ca`

## Quick Usage

- `/call-ai "prompt"` — Codex + Gemini thorough (default)
- `/call-ai :all "prompt"` — all configured models
- `/call-ai codex "prompt"` — Codex only
- `/call-ai gemini "prompt"` — Gemini only
- `/call-ai claude "prompt"` — Claude only

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:

1. `graph/index.md`
2. one MOC: `graph/mocs/execution.md` or `graph/mocs/reliability.md`
3. only required nodes under `graph/nodes/`
4. deep references/examples only when needed

## Hard Requirements

- External AIs have zero conversation context; prompt must be self-contained.
- Use `ai-registry.yaml` as model source of truth.
- Use script-defined reliability behavior (retry/backoff/timeout); do not re-implement ad-hoc loops.
- Never fail silently; always return explicit success/failure outcomes.

## Execution Router

| Stage | Load |
|------|------|
| Parse request | `graph/nodes/parse-request.md` |
| Preflight checks | `graph/nodes/preflight-check.md` |
| Select models | `graph/nodes/select-models.md` |
| Choose runner | `graph/nodes/choose-runner.md` |
| Execute | `graph/nodes/run-single-request.md` or `graph/nodes/run-parallel-requests.md` |
| Verify | `graph/nodes/verify-results.md` |
| Return | `graph/nodes/return-format.md` |

## Reliability Router

Use when debugging degraded runs:
- `graph/nodes/retry-and-timeout.md`
- `graph/nodes/handle-failures.md`

## Script Surface

- `ask-ai.sh`
- `ask-ai-runner.sh`
- `ask-ai-zellij.sh`
- `ask-ai-tmux.sh`
- `ask-ai-ghostty.sh`
- `scripts/run-parallel.sh`
- `scripts/validate-response.sh`

## References

- `references/ai-registry.md`
- `examples/single-ai.md`
- `examples/multi-ai.md`
- `examples/error-recovery.md`
- `examples/all-models.md`
