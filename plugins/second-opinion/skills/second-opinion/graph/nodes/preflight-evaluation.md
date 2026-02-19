---
id: preflight-evaluation
description: Decide whether external AIs are useful and whether clarification is needed.
status: active
tags: [node, preflight]
links:
  - [[context-build]]
---

# Preflight Evaluation

Check if external opinions are worthwhile:

- Specific enough question?
- Likely to benefit from alternative perspectives?
- Understandable without deep hidden context?
- Not a purely codebase-location question?

## If Ambiguous

Use AskUserQuestion to disambiguate scope or goal.

## If Not Suitable

State why and suggest direct local handling instead of external AI calls.

## If Suitable

Proceed to [[context-build]].
