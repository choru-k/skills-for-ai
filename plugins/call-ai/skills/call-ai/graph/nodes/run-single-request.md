---
id: run-single-request
description: Execute one AI request using selected runner and capture response artifact paths.
status: active
tags: [node, execution]
links:
  - [[verify-results]]
---

# Run Single Request

Run one provider/model invocation.

Capture and return:
- response text path
- stderr/error path when present
- metrics sidecar path when present

Use retry behavior from script defaults; do not add ad-hoc retry loops.
