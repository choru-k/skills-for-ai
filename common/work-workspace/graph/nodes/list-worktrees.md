---
id: list-worktrees
description: List git worktrees and directory-level ticket folders for a repository.
status: active
tags: [node, list]
links:
  - [[cleanup-worktrees]]
  - [[return-summary]]
---

# List Worktrees

Commands:
1. `cd ~/Desktop/clumio/<repo>/main && git worktree list`
2. `ls -la ~/Desktop/clumio/<repo>/`

Return a clear list including:
- source clone: `main/`
- registered ticket worktrees from `git worktree list`
- ticket-like directories (`CENG-*`) for quick visual confirmation

If a `CENG-*` directory exists but is missing from `git worktree list`, flag it as potential stale/manual directory.
