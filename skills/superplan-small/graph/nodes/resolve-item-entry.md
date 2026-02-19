---
id: resolve-item-entry
description: Resolve exactly one item-*.md entry to expand in small tier.
status: active
tags: [node, selection]
links:
  - [[enforce-small-scope-limits]]
---

# Resolve Item Entry

Selection priority:
1. caller-provided `item_file`
2. detect `item-*.md` and ask user to choose
3. if none, stop and instruct to run `/superplan medium`

Expand exactly one item per invocation.
