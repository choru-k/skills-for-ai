---
id: bp-personal-brain-os-filesystem
description: Use filesystem-first context architecture with progressive disclosure for personal agent workflows.
status: adopted
last_status_change: 2026-02-23
status_reason: adopted from candidate-personal-brain-os-filesystem
source: candidate-personal-brain-os-filesystem
adopted_on: 2026-02-23
owner: cheol
last_reviewed: 2026-02-23
review_by: 2026-03-25
review_interval_days: 30
tags: [best-practice, context-engineering, filesystem, progressive-disclosure]
links:
  - [[candidate-personal-brain-os-filesystem]]
  - [[status-lifecycle]]
  - [[review-best-practices]]
---

# Best Practice: Filesystem-First Personal Agent OS (with Constraints)

## Rule

For personal agent workflows, prefer a Git-versioned, filesystem-first context architecture with progressive disclosure (`router -> module instructions -> task data`) and scoped instruction hierarchy (`repo -> global -> module`) instead of loading a monolithic prompt by default.

## Why

- Reduces context overload and instruction conflicts.
- Improves consistency across repeated tasks by reusing structured context.
- Preserves history and rollback safety through Git-backed files.

## Scope

- Best for personal/small-team agent systems and knowledge workflows.
- Use append-only JSONL for logs/events where immutability is valuable.
- Do **not** treat this as a universal replacement for databases in high-concurrency or heavy-query systems.

## Implementation Checklist

- [ ] Start with one pilot workflow and define `router -> module -> data` loading boundaries.
- [ ] Keep instruction layers scoped and non-overlapping.
- [ ] Use explicit schemas for YAML/JSONL data and avoid sparse over-engineered fields.
- [ ] Measure token usage, output consistency, and maintenance overhead before expansion.
- [ ] Keep rollback simple (Git history + status updates in playbook notes).

## Periodic Review Notes

- Last outcome: keep
- Follow-ups:
  - verify pilot metrics after first review cycle
  - confirm constraints remain explicit in adopted usage guidance

## Rollback Trigger

Deprecate if maintenance overhead outweighs quality gains, or if required workflows need stronger query/concurrency guarantees than a file-based approach can provide.

## Related

- [[workflow-analyze-validate-decide-adopt]]
- [[validation-rubric]]
