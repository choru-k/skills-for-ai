---
id: bp-skill-graph-post
description: Use a thin SKILL.md router with linked graph nodes for complex skills.
status: adopted
last_status_change: 2026-02-19
status_reason: adopted from candidate-skill-graph-post
source: candidate-skill-graph-post
adopted_on: 2026-02-19
owner: cheol
last_reviewed: 2026-02-19
review_by: 2026-03-19
review_interval_days: 30
tags: [best-practice, skill-graph, architecture]
links:
  - [[candidate-skill-graph-post]]
  - [[status-lifecycle]]
  - [[review-best-practices]]
---

# Best Practice: Skill Graphs over Monolithic SKILL.md

## Rule

For complex domains, keep `SKILL.md` thin and route execution into linked graph nodes (`index -> MOC -> nodes`) instead of placing all guidance in one file.

## Why

- Improves maintainability by splitting large instructions into focused notes.
- Enables progressive disclosure and selective loading.
- Reuses knowledge across skills through links.

## Scope

Apply to high-complexity skills first (e.g., `second-opinion`, `superplan`, `work-ticket`).

## Implementation Checklist

- [x] Keep `SKILL.md` as entrypoint/router (pilot: `second-opinion`)
- [x] Add `graph/index.md` and at least one MOC (pilot: `second-opinion`)
- [x] Add focused nodes with frontmatter (`id`, `description`, `status`, `links`) (pilot: `second-opinion`)
- [x] Add/update status + review metadata in adoption log
- [ ] Add lightweight checks for broken links and missing metadata

## Periodic Review Notes

- Last outcome: keep
- Follow-ups:
  - completed pilot migration on `second-opinion` (2026-02-19)
  - completed rollout on `superplan`, `superplan-big`, `superplan-medium`, `superplan-small` (2026-02-19)
  - next: apply to `work-ticket`

## Rollback Trigger

If graph overhead outweighs value (maintenance burden, weak adoption, navigation confusion), revert specific skills to a simpler structure while keeping candidate notes as history.

## Related

- [[workflow-analyze-validate-decide-adopt]]
- [[validation-rubric]]
