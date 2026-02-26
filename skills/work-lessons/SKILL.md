---
name: work-lessons
description: |
  Log and search lessons learned working in the Clumio codebase — debug solutions, bug fixes, insights, and patterns.
  Use for "log a lesson", "save this fix", "search lessons", "what did we learn",
  "work lessons", or when capturing a root cause after debugging.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
argument-hint: "[add|search|list|update]"
---

# Work Lessons — Capture & Search Debug Knowledge

Log and search lessons learned while working in the Clumio codebase.
Entries are stored in repo-scoped lesson directories under `~/Desktop/clumio/<repo>/lessons/`.

## Storage Resolution

Resolve storage scope before each action:

1. Detect current repo from `pwd` if path is under `~/Desktop/clumio/<repo>/...`
2. If repo is detected, default scope is that repo's lessons directory
3. If no repo context (or user asks for all), scope to all existing `~/Desktop/clumio/*/lessons/` directories
4. For `add`, if target lessons directory does not exist, create it and initialize `index.md`

## Per-Repo Layout

```
~/Desktop/clumio/<repo>/lessons/
├── index.md                    # Auto-maintained catalog for this repo
└── YYYY-MM-DD-<slug>.md        # One file per entry (flat directory)
```

File naming: `YYYY-MM-DD-<slug>.md` — date prefix for chronological ordering, kebab-case slug.

## Index Format

Per-repo `index.md` uses:

```markdown
## Recent
| Date | Title | Tags |
|------|-------|------|

## All Entries
- (none yet)
```

Recent row format:

```markdown
| YYYY-MM-DD | [Title](YYYY-MM-DD-slug.md) | tag1, tag2 |
```

All Entries format:

```markdown
- [YYYY-MM-DD — Title](YYYY-MM-DD-slug.md)
```

## Determine Action

Parse the user's argument or use AskUserQuestion to determine action:

- **add** — Log a new lesson
- **search** — Find existing solutions
- **list** — Browse entries
- **update** — Modify an existing entry

---

## Action: `add` — Log a New Entry

### 1. Gather Context

Extract from the conversation or ask the user:
- **Title**: Short descriptive title of the problem
- **Problem**: Error message, symptoms observed
- **Root Cause**: Why it happened
- **Solution**: How to fix it
- **Notes**: Prevention tips, related issues (optional)

### 2. Auto-detect Metadata

Try to detect these automatically before asking:

**repo** — from current working directory:
```bash
pwd
```
If no repo is detected, ask user which repo this lesson belongs to.

**ticket** — extract from current git branch:
```bash
git branch --show-current 2>/dev/null || echo ""
```
Look for pattern `CENG-\d+` in the branch name.

**date** — use today's date (YYYY-MM-DD).

### 3. Resolve Target Directory

Set:
- `LESSONS_DIR=~/Desktop/clumio/<repo>/lessons`
- `ENTRY_PATH=$LESSONS_DIR/YYYY-MM-DD-<slug>.md`

If `LESSONS_DIR` is missing, create it.
If `index.md` is missing, create it using the index format in this skill.

### 4. Ask for Tags

Use AskUserQuestion to suggest tags based on the content. Always include `work-lessons` as the first tag.

Common tag categories:
- Infrastructure: `terraform`, `terragrunt`, `helm`, `kubernetes`, `helmfile`, `docker`
- Languages: `go`, `python`, `typescript`, `groovy`
- Services: `web`, `catalog`, `foothill`, `omega`, `dynamite`, `daebak`, `policy`, `tasks`
- Operations: `ci-cd`, `jenkins`, `github-actions`, `deployment`, `monitoring`
- Issues: `state-lock`, `vendor`, `dependency`, `build`, `test`, `lint`, `config`

### 5. Ask for Severity

Use AskUserQuestion:
- **low** — Minor annoyance, easy workaround
- **medium** — Caused noticeable delay, non-obvious fix
- **high** — Significant time lost, hard to diagnose
- **critical** — Outage-level or data-affecting

### 6. Generate Entry File

Generate slug from title: lowercase, replace spaces with hyphens, remove special characters, max 50 chars.

Filename: `YYYY-MM-DD-<slug>.md`

Use the template from `references/entry-template.md` and write to:
- `~/Desktop/clumio/<repo>/lessons/<filename>`

### 7. Update Repo Index

Read `~/Desktop/clumio/<repo>/lessons/index.md` and update:

1. Add a new row to **Recent** (insert at top, keep reverse-chronological order)
2. Add a link under **All Entries**

If **All Entries** contains `- (none yet)`, replace it with the new entry.

### 8. Confirm

Tell the user:
- repo and file path created
- tags applied
- they can view it in Obsidian

---

## Action: `search` — Find Existing Solutions

### 1. Resolve Search Scope

- If repo is explicit or detectable from cwd, search that repo's lessons directory first
- If user asks broader search or no repo context exists, search all `~/Desktop/clumio/*/lessons/`

### 2. Get Search Query

Take query from user argument or ask for it.

### 3. Search Strategy

Run these searches in order, stop early if exact matches are sufficient:

1. tag search
2. body content search (case-insensitive)
3. filename search

### 4. Present Results

For each match:
1. Read the file
2. Show: **Title** | **Date** | **Repo** | **Tags**
3. Show the **Problem** summary (first 2-3 lines)

If multiple matches, present numbered list and let user pick one for full view.

If no matches, suggest `/work-lessons add`.

---

## Action: `list` — Browse Entries

### 1. Resolve List Scope

- Repo scope: read `~/Desktop/clumio/<repo>/lessons/index.md`
- Global scope: read each existing `~/Desktop/clumio/*/lessons/index.md` and present grouped by repo

### 2. Optional Filtering

If user provided a filter (tag/repo/keyword):
- filter index content first
- fall back to content grep across in-scope lesson files

### 3. Detail View

Offer to open any listed entry and show full content.

---

## Action: `update` — Modify Existing Entry

### 1. Find the Entry

Use `search` or `list` to locate target entry.

### 2. Read Current Content

Read full entry file before editing.

### 3. Apply Changes

Use Edit tool for requested changes.

Supported updates:
- Add notes or context
- Improve solution section
- Add/change tags
- Update severity
- Fix content errors

### 4. Update Index if Needed

If title or tags changed, update the matching row/link in that repo's `index.md`.

---

## Integration Notes

- After resolving a bug during `/work-ticket`, suggest `/work-lessons add`
- Auto-detect `repo` and `ticket` from current git worktree context via `/work-workspace`
- Use Obsidian-compatible markdown and wiki-links where helpful
