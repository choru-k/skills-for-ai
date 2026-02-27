---
name: work-workspace
description: Manage git worktrees for work repositories. Use for "create worktree", "setup work repo", "switch worktree", or git worktree operations.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Work Git Worktree Management

Manage git worktrees across work repositories for parallel development on multiple tickets.

## Progressive Loading Contract (Skill Graph)

For each invocation, load in order:

1. `graph/index.md`
2. one MOC: `graph/mocs/routing.md`, `graph/mocs/worktree-ops.md`, or `graph/mocs/maintenance.md`
3. only required node files under `graph/nodes/`
4. deep reference only when needed: `references/repos.md`

## Hard Rules

1. Keep repository roots under `~/Desktop/clumio/<repo>/` with source clone in `main/`.
2. Never treat `main/` as ticket worktree.
3. Run `git fetch origin` from `~/Desktop/clumio/<repo>/main` before creating new worktrees.
4. Create branches from `origin/<target_branch>` (never from current local HEAD by default).
5. Worktree folder names must be ticket-based: `CENG-####` or `CENG-####-<suffix>` when parallel efforts are needed.
6. Use explicit confirmation before destructive cleanup actions.

## Route by Intent

| Intent | MOC |
|------|------|
| Decide action/repo/ticket | `graph/mocs/routing.md` |
| Setup/create/switch/list | `graph/mocs/worktree-ops.md` |
| Cleanup/stale maintenance | `graph/mocs/maintenance.md` |

## Core Flows

### Routing Flow

| Stage | Load |
|------|------|
| Determine action | `graph/nodes/determine-action.md` |
| Select repository | `graph/nodes/select-repository.md` |
| Extract ticket (when needed) | `graph/nodes/extract-ticket-number.md` |

### Worktree Ops Flow

| Stage | Load |
|------|------|
| Setup repository | `graph/nodes/setup-repository.md` |
| Create worktree | `graph/nodes/create-worktree.md` |
| Switch worktree | `graph/nodes/switch-worktree.md` |
| List worktrees | `graph/nodes/list-worktrees.md` |
| Post-create integration | `graph/nodes/post-create-integration.md` |
| Return summary | `graph/nodes/return-summary.md` |

### Maintenance Flow

| Stage | Load |
|------|------|
| List worktrees | `graph/nodes/list-worktrees.md` |
| Cleanup worktrees | `graph/nodes/cleanup-worktrees.md` |
| Return summary | `graph/nodes/return-summary.md` |

## Supported Repositories

- `argocd-deployments`
- `argocd-dev`
- `cdf`
- `infra-charts`
- `infra-kubernetes`
- `infra-terraform`
- `jenkins-ci-lib`
- `jenkins-lib`
- `jenkins-system`
- `jenkins_publish`
- `jobutil`
- `terraform-provider-clumio-internal`
- `tf-aws-sso-permissionsets`

Canonical mapping and examples: `references/repos.md`.

## Integration with work-ticket

After creating a worktree, offer:
- switch to new worktree path
- open `/work-ticket` (or `/wt`) for planning and progress tracking

## Important Notes

- Worktree directories should be ticket-based and may include a suffix (example: `CENG-5721-ce`).
- Existing legacy branches/directories may not follow the latest naming convention; do not rename automatically.
- Use `git worktree prune` to clean stale references when needed.
