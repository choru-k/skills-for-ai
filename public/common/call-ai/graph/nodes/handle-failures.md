---
id: handle-failures
description: Handle partial and full failures with explicit, non-silent reporting.
status: active
tags: [node, failure]
links:
  - [[return-format]]
---

# Handle Failures

Rules:
- never fail silently
- if some models fail, return successful responses plus clear failure notes
- if all fail, return consolidated troubleshooting summary

Include likely cause hints (auth, rate-limit, timeout, context length, missing CLI).
