---
id: workflow-analyze-validate-decide-adopt
description: Canonical loop for deciding whether an external idea becomes a best practice.
status: active
tags: [workflow, governance]
links:
  - [[validation-rubric]]
  - [[status-lifecycle]]
  - [[review-best-practices]]
---

# Analyze → Validate → Decide → Adopt

## 1) Analyze the Resource

Capture:
- source URL/title
- key claim(s)
- context (who, where, problem space)

## 2) Validate the Idea

Use [[validation-rubric]] and produce:
- verdict (`valid`, `valid-with-constraints`, `not-valid`, `unknown`)
- confidence (`high`, `medium`, `low`)
- assumptions and risks

## 3) User Decision Gate

Ask explicit decision:
- adopt now
- keep as candidate
- reject

No adoption without user approval.

## 4) Record Status

Apply status via [[status-lifecycle]] and update:
- candidate/bp note frontmatter
- `adoption.md`

## 5) Adopt + Maintain

When approved:
1. create `bp-<slug>.md`
2. link from `graph/mocs/standards.md`
3. set review metadata (`last_reviewed`, `review_by`)
4. periodically run [[review-best-practices]]
