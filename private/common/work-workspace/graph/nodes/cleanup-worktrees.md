---
id: cleanup-worktrees
description: Remove stale/merged worktrees with explicit user confirmation.
status: active
tags: [node, cleanup]
links:
  - [[return-summary]]
---

# Cleanup Worktrees

Flow:
1. list current worktrees (`git worktree list`) with directory + branch
2. ask user which exact worktree directory to remove (example: `CENG-5721-ce`)
3. run `git worktree remove ../<WORKTREE_DIR>` from `main/`
4. run `git worktree prune`
5. optionally ask and delete remote branch using the selected worktree's actual branch name

Optional remote cleanup:
- `git push origin --delete <selected-branch-name>`

Rules:
- always ask confirmation before remove/delete
- do not reconstruct branch names when exact branch is already known from `git worktree list`
