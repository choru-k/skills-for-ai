---
id: resolve-root-target
description: Resolve and confirm target_directory as ticket root for big-tier outputs.
status: active
tags: [node, target]
links:
  - [[gather-big-requirements]]
---

# Resolve Root Target

Use caller-provided `target_directory` as the ticket root.

All outputs for this tier must remain in this root:
- `main.md`
- `phase-*.md`

Do not create `phase-*` directories in this tier.
