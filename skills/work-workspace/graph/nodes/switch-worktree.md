---
id: switch-worktree
description: Switch context to an existing ticket worktree path.
status: active
tags: [node, switch]
links:
  - [[return-summary]]
---

# Switch Worktree

Worktree paths are under:
- `~/Desktop/clumio/<repo>/`

Matching rules:
1. if user gives full worktree directory name (example: `CENG-5721-ce`), use exact match
2. if user gives ticket only (example: `CENG-5721`), match all `CENG-5721*` directories
3. if multiple matches exist, ask user to choose one

If selected path exists, switch context there and report success.
If missing, suggest creating the worktree first.
