---
id: select-models
description: Resolve concrete model list from ai spec using ai-registry as source of truth.
status: active
tags: [node, models]
links:
  - [[choose-runner]]
---

# Select Models

Resolve target models from `ai-registry.yaml`.

Rules:
- default -> codex + gemini thorough
- `:all` -> all configured models
- single AI spec -> one model unless user asks for variants

If model mapping is unclear, read `references/ai-registry.md`.
