---
id: review-best-practices
description: Periodic review process for all adopted best practices.
status: active
tags: [review, maintenance]
links:
  - [[status-lifecycle]]
  - [[validation-rubric]]
---

# Review Best Practices

Run this on a periodic cadence (for example monthly).

## Scope

Review all `bp-*.md` where `status: adopted`.

## Per-Practice Checklist

1. Is the original problem still relevant?
2. Is the practice still compatible with current tooling/workflow?
3. Is the cost still justified?
4. Is there a better replacement?

## Review Outcomes

- `keep` — remain `adopted`
- `revise` — remain `adopted`, add update task
- `deprecate` — change status to `deprecated`

## Required Updates

For each reviewed practice, update:
- `last_reviewed`
- `review_by`
- `status` (if deprecated)
- `status_reason` (if status changed)

Run `scripts/graph-qa.sh` after updates.

Also update `adoption.md` and write `reviews/YYYY-MM-DD.md`.
