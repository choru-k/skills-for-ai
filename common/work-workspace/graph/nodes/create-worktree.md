---
id: create-worktree
description: Create ticket worktree and branch from selected target branch.
status: active
tags: [node, create]
links:
  - [[post-create-integration]]
  - [[return-summary]]
---

# Create Worktree

Before create, ask for:
- target branch (default `main`)
- summary slug (2-3 words)
- optional worktree suffix when needed (example: `ce`, `phase2`)

Branch naming pattern (recommended):
- `user/choru/${TICKET}_${SUMMARY}/${TARGET_BRANCH}`

Worktree folder name:
- default: `${TICKET}`
- with suffix: `${TICKET}-${SUFFIX}`

Execution:
1. `cd ~/Desktop/clumio/<repo>/main`
2. `git fetch origin`
3. build `worktree_dir` from ticket + optional suffix
4. if `~/Desktop/clumio/<repo>/<worktree_dir>/` already exists, ask for a different suffix or offer switch instead of create
5. `git worktree add ../<worktree_dir> -b <branch-name> origin/<TARGET_BRANCH>`

Worktree directory:
- `~/Desktop/clumio/<repo>/<worktree_dir>/`

Notes:
- Always create from `origin/<TARGET_BRANCH>` (not current local HEAD).
- If user explicitly asks to reuse an existing branch, follow user intent and avoid forced renaming.
