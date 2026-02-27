---
id: detect-legacy-layout
description: Detect old flat plan layouts and route user to migration decision.
status: active
tags: [node, migration]
links:
  - [[migrate-single-project]]
---

# Detect Legacy Layout

Legacy markers in project root:
- `task-*.md`
- `phase-*.md`
- plan-style `main.md` with `tier: small|medium|big` and missing/empty `plans/`

If detected, ask whether to migrate now:
- migrate now (recommended)
- not now (compatibility mode)
