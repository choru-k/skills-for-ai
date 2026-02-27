---
id: execution
description: Execution flow for parsing request, selecting models, running AI calls, and returning results.
status: active
tags: [moc, execution]
links:
  - [[parse-request]]
  - [[preflight-check]]
  - [[select-models]]
  - [[choose-runner]]
  - [[run-single-request]]
  - [[run-parallel-requests]]
  - [[verify-results]]
  - [[return-format]]
---

# Execution MOC

## Flow

1. [[parse-request]]
2. [[preflight-check]]
3. [[select-models]]
4. [[choose-runner]]
5. run path:
   - [[run-single-request]] or
   - [[run-parallel-requests]]
6. [[verify-results]]
7. [[return-format]]
