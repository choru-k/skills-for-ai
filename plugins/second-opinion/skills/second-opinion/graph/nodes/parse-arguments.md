---
id: parse-arguments
description: Parse AI target selector and user question from /so input.
status: active
tags: [node, parsing]
links:
  - [[preflight-evaluation]]
---

# Parse Arguments

## Inputs

User input in one of these forms:
- `/so "question"`
- `/so :all "question"`
- `/so codex "question"`
- `/so gemini "question"`
- `/so claude "question"`

## Parsing Rules

- `AI_SPEC`: first token if in `{codex, gemini, claude, :all}`
- `QUESTION`: remaining text
- Default if AI spec omitted: `codex + gemini` (2 responses)

## Validation

- If `QUESTION` is empty or vague, ask user to clarify.
- Preserve exact question wording unless user asks to rewrite.

## Output Contract

- `AI_SPEC`
- `QUESTION`
- `EXPECTED_RESPONSE_COUNT` (1, 2, or 6)
