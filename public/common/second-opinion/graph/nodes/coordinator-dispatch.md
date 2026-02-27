---
id: coordinator-dispatch
description: Spawn Sonnet coordinator that calls external AIs and returns raw responses.
status: active
tags: [node, orchestration]
links:
  - [[response-verification]]
---

# Coordinator Dispatch

## Steps

1. Read `templates/coordinator-prompt.md`.
2. Resolve `CALL_AI_DIR`:
   - try `../call-ai/`
   - fallback `~/.claude/skills/call-ai/`
   - choose first path containing `ai-registry.yaml`
3. Replace placeholders:
   - `{{AI_SPEC}}`
   - `{{PROMPT_FILE_PATH}}`
   - `{{CALL_AI_DIR}}`
4. Spawn Task sub-agent:
   - type: general-purpose
   - model: sonnet
   - description: Coordinate AI calls

## Expected Results

- default: 2 responses
- single AI: 1 response
- `:all`: 6 responses

Coordinator must return raw response paths.
