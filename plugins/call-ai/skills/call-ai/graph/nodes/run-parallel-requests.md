---
id: run-parallel-requests
description: Execute multi-model request in parallel and collect delimited results.
status: active
tags: [node, execution, parallel]
links:
  - [[retry-and-timeout]]
  - [[verify-results]]
---

# Run Parallel Requests

Use `scripts/run-parallel.sh` with provider/model pairs.

Expect delimited output blocks:
- `=== RESULT: <ai> <model> ===`
- `=== END ===`

Collect per-model artifacts and preserve order in final report.
