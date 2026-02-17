---
name: clarify
description: Turn ambiguous requests into clean, actionable specifications. Use for "clarify", "clarify requirements", "this is vague", "make this clean", "spec this out", "scope this", "요구사항 명확히", or when the user's intent is unclear.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Clarify: Ambiguous Request → Clean Spec

Transform vague user requests into precise, executable requirements.

## Hard Rules

1. Use **AskUserQuestion** (or Pi `ask`) for clarification.
2. Do not ask open-ended clarifying questions when options can be provided.
3. Ask **max 8 questions total**.
4. Batch related questions (up to 4 per round).
5. End with a concrete **before/after** summary.
6. If already clear, skip questioning and produce the cleaned spec directly.

## Core Principle: Hypothesis-as-Options

Give plausible interpretations as options so the user can choose quickly.

- Bad: "What kind of auth do you want?"
- Good: "Email+Password / OAuth / Magic Link / SSO"

## Workflow

### 1) Capture Original Request

Record the user's original wording verbatim.

### 2) Diagnose Ambiguity

Check which areas are unclear:
- Scope (in/out)
- Target user/actor
- Behavior and edge cases
- Interface (API/UI/CLI)
- Data format/source
- Constraints (time, cost, performance, security)
- Priority and timeline

### 3) Clarify with Structured Questions

Ask only what is required to make implementation unambiguous.

Use AskUserQuestion/ask with multiple-choice options. Prefer single-choice unless compound causes are likely.

Example shape (adapt to tool schema in current harness):

```yaml
questions:
  - id: scope
    question: "What scope should this include right now?"
    options:
      - label: "MVP only"
        description: "Smallest useful version"
      - label: "Core + edge cases"
        description: "Main flow plus common exceptions"
      - label: "Production-ready"
        description: "Includes hardening and ops concerns"
  - id: interface
    question: "Where should this be implemented first?"
    options:
      - label: "API first"
      - label: "UI first"
      - label: "CLI first"
```

Stop when:
- Critical ambiguities are resolved, or
- User says "good enough", or
- Question cap reached.

### 4) Produce Cleaned Spec

Return this format:

```markdown
## Clarification Summary

### Before (Original)
"{original request}"

### After (Clean Spec)
- **Goal**: ...
- **Scope In**: ...
- **Scope Out**: ...
- **Constraints**: ...
- **Success Criteria**: ...
- **Priority/Timeline**: ...

### Decisions Made
| Topic | Decision |
|------|----------|
| Scope | ... |
| Interface | ... |
| Constraints | ... |
```

### 5) Offer Save

Ask if user wants this saved to a file.

Default path suggestion:
- `requirements/<slug>.md`

If user agrees, write the file and confirm path.

## Guardrails

- Do not over-question; minimize user effort.
- Do not invent constraints not chosen by user.
- Preserve user intent; clarify precision, not direction.
- Highlight unresolved items explicitly as `Open Questions`.
