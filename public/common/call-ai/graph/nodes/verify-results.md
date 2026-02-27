---
id: verify-results
description: Validate completeness and basic response quality before final output.
status: active
tags: [node, verification]
links:
  - [[return-format]]
---

# Verify Results

Before returning:
- check expected count vs collected results
- detect obvious empty/error-only responses
- if needed, use `scripts/validate-response.sh` for stricter checks

Proceed with caveats when partially degraded.
