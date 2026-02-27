---
id: execution
description: Execution MOC for argument parsing, context generation, coordinator dispatch, and verification.
status: active
tags: [moc, execution]
links:
  - [[parse-arguments]]
  - [[preflight-evaluation]]
  - [[context-build]]
  - [[coordinator-dispatch]]
  - [[response-verification]]
  - [[synthesis-strategy]]
---

# Execution MOC

## Main Flow

1. [[parse-arguments]]
2. [[preflight-evaluation]]
3. [[context-build]]
4. [[coordinator-dispatch]]
5. [[response-verification]]
6. [[synthesis-strategy]]

## Load-on-Demand Guidance

- If user input is ambiguous, prioritize [[parse-arguments]] + [[preflight-evaluation]].
- If orchestration is failing, jump to [[coordinator-dispatch]] then `reference/troubleshooting.md`.
- If only quality check is needed, read [[response-verification]] only.

## Deep Reference

- `reference/workflow.md`
