---
name: complete-prompt
description: |
  Generate context prompts for AI-to-AI handoffs. Use when sharing conversation
  context, continuing work in a fresh session, or handing off to another LLM.
  Supports full, brief, debug, architect, diff, general, research, career, and learning modes.
  Use for "cp", "complete prompt", "context prompt", "handoff prompt", "share context", or "hand off to another AI".
user-invocable: true
allowed-tools: Read, Write, Bash, AskUserQuestion
argument-hint: "[full|brief|debug|architect|diff|general|research|career|learning] [--refs]"
---

# Complete Prompt

Generate a self-contained handoff prompt from the current conversation context.

**Alias:** `/cp`

## Quick Usage

- `/cp` -> full mode (default)
- `/cp brief`
- `/cp debug`
- `/cp architect`
- `/cp diff`
- `/cp general`
- `/cp research`
- `/cp career`
- `/cp learning`
- add `--refs` to any mode for reference-only file sections

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:

1. `graph/index.md`
2. one MOC: `graph/mocs/generation.md`, `graph/mocs/mode-routing.md`, or `graph/mocs/output.md`
3. only required nodes under `graph/nodes/`
4. deep references/examples only when needed

## Hard Requirements

- Main agent performs generation directly (no context-losing sub-agent for extraction).
- Always load template from disk (`templates/<mode>.xml`); do not invent schema.
- Use `--refs` only when receiving AI can access the same codebase.
- Do not leak secrets in generated output.
- Save output to `.prompts/<timestamp>-<mode>.xml` and return path.

## Generation Router

| Stage | Load |
|------|------|
| Parse args | `graph/nodes/parse-mode-and-flags.md` |
| Select mode | `graph/nodes/select-mode.md` |
| Extract context | `graph/nodes/extract-conversation-context.md` |
| Preflight checks | `graph/nodes/run-preflight-checklist.md` |
| Token/safety policy | `graph/nodes/token-and-safety-guidelines.md` |
| Apply refs strategy | `graph/nodes/apply-refs-strategy.md` |
| Load template | `graph/nodes/load-template.md` |
| Populate XML | `graph/nodes/populate-template.md` |
| Save file | `graph/nodes/save-output-file.md` |
| Validate | `graph/nodes/validate-output-file.md` |
| Return | `graph/nodes/return-result.md` |

## Artifacts

- output directory: `.prompts/`
- validator: `validate.sh`

## References

- `templates/*.xml`
- `examples/full.md`
- `examples/brief.md`
- `examples/debug.md`
- `examples/architect.md`
- `examples/diff.md`
- `README.md`
