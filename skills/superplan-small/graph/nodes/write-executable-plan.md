---
id: write-executable-plan
description: Write executable plan.md with required queues, findings, and approval sections.
status: active
tags: [node, output, plan]
links:
  - [[update-parent-item-entry]]
---

# Write Executable plan.md

Create `item-<N>/plan.md` with:

## Execution Contract (required)

- Always follow this file.
- Pick next unchecked actionable item by priority: `ISSUE` -> `TEST` -> `STRUCT`.
- `ISSUE` and `TEST` follow Red -> Green -> Refactor.
- `ISSUE` must add a failing regression test first.
- Run fast full tests after each cycle.
- Mark completed item and continue until no required unchecked items remain, blocked, or interrupted.

## Required Sections

- TEST queue (required)
- STRUCT queue (optional)
- `## Quality Findings`
- `## Architecture Findings`
- `## Security Findings`
- `## Performance Findings`
- `## Tester Findings`
- `## Approval`
- fast suite commands

Ensure plan is directly executable by coder + reviewer + tester loop.
