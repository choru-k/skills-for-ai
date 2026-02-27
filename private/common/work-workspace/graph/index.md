---
id: work-workspace-index
description: Entrypoint for git worktree management across work repositories.
status: active
tags: [index, work-workspace]
links:
  - [[routing]]
  - [[worktree-ops]]
  - [[maintenance]]
---

# Work-Workspace Graph Index

Use this index first, then load only needed MOC and nodes.

## Progressive Disclosure

1. `graph/index.md`
2. one MOC (`[[routing]]`, `[[worktree-ops]]`, or `[[maintenance]]`)
3. required node(s)
4. deep reference when needed: `references/repos.md`

## Invariants

- Repositories live under `~/Desktop/clumio/<repo>/`.
- `main/` is source clone; ticket work occurs in sibling worktrees.
- Worktree folders are ticket-based: `CENG-####` or `CENG-####-<suffix>`.
- `git fetch origin` before new worktree creation.
- Create from `origin/<target_branch>` rather than current local HEAD.
