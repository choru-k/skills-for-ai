---
id: resolve-phase-entry
description: Resolve exactly one root phase-*.md entry to expand.
status: active
tags: [node, selection]
links:
  - [[create-phase-directory]]
---

# Resolve Phase Entry

Selection priority:
1. caller-provided `phase_file`
2. detect root `phase-*.md` and ask user to choose
3. if none, stop and instruct to run `/superplan big`

Expand exactly one phase per invocation.
