---
id: token-and-safety-guidelines
description: Token budgeting and safety constraints for prompt generation.
status: active
tags: [node, policy]
links:
  - [[run-preflight-checklist]]
  - [[apply-refs-strategy]]
---

# Token and Safety Guidelines

Guidelines:
- prefer signal over verbosity
- include enough context for continuation, not entire chat transcript noise
- avoid secret leakage
- state assumptions and unknowns explicitly

Use mode-appropriate token budgets and refs mode when applicable.
