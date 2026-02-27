---
id: status-lifecycle
description: Allowed statuses and transitions for candidates and best-practice notes.
status: active
tags: [status, governance]
links:
  - [[workflow-analyze-validate-decide-adopt]]
  - [[review-best-practices]]
---

# Status Lifecycle

## Status Values

- `proposed` — captured, not approved
- `piloting` — being tested in limited scope
- `adopted` — approved and active best practice
- `rejected` — evaluated and declined
- `deprecated` — previously adopted but no longer recommended

## Typical Transitions

- `proposed -> piloting`
- `proposed -> adopted`
- `proposed -> rejected`
- `piloting -> adopted`
- `piloting -> rejected`
- `adopted -> deprecated`

Avoid direct `rejected -> adopted`. Re-open by setting to `proposed` first.

## Required Metadata on Status Change

- `status`
- `last_status_change` (YYYY-MM-DD)
- `status_reason` (short line)
