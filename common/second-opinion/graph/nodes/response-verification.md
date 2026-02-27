---
id: response-verification
description: Verify completeness and quality of external AI responses before synthesis.
status: active
tags: [node, verification]
links:
  - [[synthesis-strategy]]
---

# Response Verification

## Completeness Check

- Confirm received count matches `EXPECTED_RESPONSE_COUNT`.

## Quality Check

Flag responses that are:
- very short / non-substantive
- pure error output
- likely truncated

## Decision

- All good: continue to synthesis.
- Partial issues: continue with explicit caveats.
- Total failure: report failure and propose retry/troubleshooting.

## Deep Reference

- `reference/workflow.md#step-5-verify-responses`
