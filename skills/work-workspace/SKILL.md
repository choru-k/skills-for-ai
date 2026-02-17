---
name: work-workspace
description: Manage git worktrees for work repositories. Use for "create worktree", "setup work repo", "switch worktree", or git worktree operations.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Work Git Worktree Management

Manage git worktrees across work repositories for parallel development on multiple tickets.

## Directory Structure

```
~/Desktop/clumio/
├── jenkins-lib/
│   ├── main/           # Git source (cloned from GitHub)
│   └── CENG-xxxx/      # Worktrees for tickets
├── infra-kubernetes/
│   ├── main/
│   └── CENG-xxxx/
├── infra-charts/
│   ├── main/
│   └── CENG-xxxx/
└── cdf/
    ├── main/
    └── CENG-xxxx/
```

## Workflow

### 1. Determine Action

Use AskUserQuestion to ask what action the user wants:

- **Setup** - Clone a repo to `~/Desktop/clumio/REPO/main/`
- **Create** - Add a worktree for a ticket (CENG-xxxx)
- **Switch** - Navigate to an existing worktree
- **List** - Show all worktrees for a repo
- **Cleanup** - Remove merged/stale worktrees

### 2. Select Repository

If action requires a repo, ask which one using AskUserQuestion with options:
- jenkins-lib
- infra-kubernetes
- infra-charts
- cdf

See `references/repos.md` for full repo URLs.

### 3. Extract Ticket Number (for create/switch)

First, try to extract from current git branch:

```bash
git branch --show-current 2>/dev/null || echo ""
```

Look for pattern `CENG-\d+` in the branch name.

If not found, use AskUserQuestion:
- Question: "What is the ticket number (e.g., CENG-1234)?"
- Header: "Ticket"

### 4. Execute Action

#### Setup (Clone Repo)

```bash
CLUMIO_DIR=~/Desktop/clumio
REPO=jenkins-lib  # or selected repo

mkdir -p "$CLUMIO_DIR/$REPO"
gh repo clone "clumio/$REPO" "$CLUMIO_DIR/$REPO/main"
```

#### Create Worktree

Before creating, ask for branch details using AskUserQuestion:
- Target branch (default: main)
- Brief summary for branch name (2-3 words, will be slugified)

Branch naming pattern: `user/choru/${TICKET}_${SUMMARY}/${TARGET_BRANCH}`

Example: `user/choru/CENG-1234_add-retry-logic/main`

```bash
CLUMIO_DIR=~/Desktop/clumio
REPO=jenkins-lib
TICKET=CENG-1234
SUMMARY="add-retry-logic"
TARGET_BRANCH="main"

cd "$CLUMIO_DIR/$REPO/main"
git fetch origin
git worktree add "../$TICKET" -b "user/choru/${TICKET}_${SUMMARY}/${TARGET_BRANCH}" "origin/${TARGET_BRANCH}"
```

After creating worktree, offer to:
1. Change to the new worktree directory
2. Open ticket planning with `/work-ticket` (or `/wt`)

#### Switch to Worktree

```bash
CLUMIO_DIR=~/Desktop/clumio
REPO=jenkins-lib
TICKET=CENG-1234

cd "$CLUMIO_DIR/$REPO/$TICKET"
```

Inform user of the directory change.

#### List Worktrees

```bash
CLUMIO_DIR=~/Desktop/clumio
REPO=jenkins-lib

cd "$CLUMIO_DIR/$REPO/main"
git worktree list
```

Also list directories in the repo folder:
```bash
ls -la "$CLUMIO_DIR/$REPO/"
```

#### Cleanup Worktrees

List worktrees first, then ask which to remove:

```bash
cd "$CLUMIO_DIR/$REPO/main"
git worktree list
```

Use AskUserQuestion to confirm which worktree to remove.

```bash
TICKET=CENG-1234
git worktree remove "../$TICKET"
```

For merged branches, also delete the remote branch if desired:
```bash
git push origin --delete "user/choru/${TICKET}_${SUMMARY}/${TARGET_BRANCH}"
```

## Integration with work-ticket

The `/work-ticket` (or `/wt`) skill manages ticket plans in Obsidian.

Obsidian ticket structure:
```
~/Desktop/choru/choru-notes/clumio/
├── CENG-1234/
│   ├── main.md           # Main plan file with status
│   ├── api-design.md     # Task-specific notes
│   └── testing-plan.md
└── CENG-5678/
    └── main.md
```

After creating a worktree, suggest using `/wt` to:
- Create or update the ticket plan in Obsidian
- Track implementation progress with checklists
- Document design decisions and notes

## Important Notes

- Always use `git fetch origin` before creating worktrees to ensure latest refs
- Worktree directories are named by ticket number for easy identification
- The main directory should never be modified directly for ticket work
- Use `git worktree prune` to clean up stale worktree references
