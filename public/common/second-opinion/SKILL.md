---
name: second-opinion
description: Gets second opinions from external AIs (Codex, Gemini, Claude) on programming questions. Use when seeking alternative perspectives, validating architectural decisions, comparing approaches, or wanting fresh eyes on a problem. Triggers on "second opinion", "what do other AIs think", "ask codex/gemini".
version: "1.3"
user-invocable: true
allowed-tools: Read, Skill, Task, AskUserQuestion
---

# Second Opinion

Get external AI perspectives on a question. Composes `/complete-prompt` + `/call-ai`.

**Alias:** `/so`

## Quick Reference

| Command | AIs Called | Responses |
|---------|------------|-----------|
| `/so "question"` | Codex + Gemini thorough | 2 |
| `/so :all "question"` | All 3 AIs × both variants | 6 |
| `/so codex "question"` | Codex thorough only | 1 |
| `/so gemini "question"` | Gemini thorough only | 1 |
| `/so claude "question"` | Claude sonnet (fresh context) | 1 |

> **AI Registry:** `<call-ai skill>/ai-registry.yaml`

## Progressive Loading Contract (Skill Graph)

For every run, load context in this order:

1. `graph/index.md`
2. One MOC: `graph/mocs/execution.md` or `graph/mocs/synthesis.md`
3. Only required node files under `graph/nodes/`
4. Deep references (`reference/*.md`, `examples/*`) only when needed

## Execution Router

| Stage | Load |
|------|------|
| Parse input | `graph/nodes/parse-arguments.md` |
| Suitability check | `graph/nodes/preflight-evaluation.md` |
| Build context | `graph/nodes/context-build.md` |
| Dispatch coordinator | `graph/nodes/coordinator-dispatch.md` |
| Verify responses | `graph/nodes/response-verification.md` |
| Synthesize | `graph/nodes/synthesis-strategy.md` |

## Hard Requirements

- External AIs have **zero** conversation context.
- Always generate handoff context via `/complete-prompt` using the Skill tool.
- Always pass `--refs` to `/complete-prompt` when external AIs can read the same codebase.
- Never manually reconstruct complete-prompt XML.
- Return both synthesis and raw response file paths.

## Success Criteria

- [ ] `/complete-prompt` invoked and returned file path
- [ ] All requested AI responses collected
- [ ] Responses saved to `.responses/`
- [ ] Synthesis highlights agreements/disagreements
- [ ] User can access raw responses via file paths

## References

### Skill Graph

| Topic | Location |
|-------|----------|
| Graph entrypoint | `graph/index.md` |
| Execution MOC | `graph/mocs/execution.md` |
| Synthesis MOC | `graph/mocs/synthesis.md` |

### Deep References

| Topic | Location |
|-------|----------|
| Detailed workflow steps | `reference/workflow.md` |
| Synthesis & merging rules | `reference/synthesis-guide.md` |
| Architecture diagram | `reference/architecture.md` |
| Error handling | `reference/troubleshooting.md` |
| Coordinator template | `templates/coordinator-prompt.md` |
| Examples | `examples/` |
