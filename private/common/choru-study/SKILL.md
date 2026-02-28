---
name: choru-study
description: Import and manage study plans in Obsidian vault. Use for "choru-study", "study", "import study plan", "track learning", or managing study materials.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# Study Plan Management

Import study plans from external locations into Obsidian vault for tracking and management.

## Workflow

### 1. Determine Source File

If a file path is provided as an argument, use it directly.

Otherwise, use AskUserQuestion to ask:
- Question: "What is the path to the study plan file?"
- Header: "Source"

Validate the file exists:
```bash
test -f "$FILE_PATH" && echo "exists" || echo "not found"
```

### 2. Parse Study Plan Title

Read the source file and extract the title from the first H1 heading (`# Title`).

If no H1 found, derive title from filename:
- `go-context-study-plan.md` → "Go Context Study Plan"

### 3. Set Obsidian Destination

Study plans are stored in:
```
~/Desktop/choru/choru-notes/1-projects/learning/
├── go-context/
│   ├── main.md           # Main study file with progress tracking
│   └── notes.md          # Personal notes (optional)
├── kubernetes-basics/
└── ...
```

Folder name is derived from the title (slugified, lowercase, hyphens).

### 4. Check for Existing Study

Before importing, check if the study folder already exists:

1. If exists in `1-projects/learning/`:
   - Read `main.md` to show current progress
   - Ask user what to do:
     - **Update** - Replace content, preserve progress checkboxes
     - **Reset** - Start fresh
     - **Cancel** - Do nothing

2. If exists in `4-archive/learning/`:
   - Inform user this study was previously archived
   - Ask if they want to reopen (move back to `1-projects/learning/`)

3. If new:
   - Create the folder structure

### 5. Import Study Plan

Transform the source file into Obsidian-friendly format:

1. **Add progress tracking** - Convert section headers into checkboxes
2. **Preserve code blocks** - Keep all code examples intact
3. **Add metadata header** - Include source path and import date

#### main.md Template

```markdown
---
type: project
status: active
start-date: YYYY-MM-DD
area: career
source: ~/path/to/original/file.md
imported: YYYY-MM-DD
last_reviewed:
tags:
  - learning
---

# [Study Title]

## Progress

- [ ] Section 1: [First H2 title]
- [ ] Section 2: [Second H2 title]
- [ ] Section 3: ...

---

[Original content with headers preserved]

---

## My Notes

[Space for personal notes while studying]
```

### 6. Report Success

After importing, display:
- Destination path
- Number of sections to study
- Command to open in Obsidian (if available)

## Actions

Based on user request:

1. **Import new study** - Copy external file to Obsidian with tracking
2. **Check progress** - Read and summarize study progress
3. **Mark complete** - Update checkbox for a section
4. **Add notes** - Append notes to study file
5. **List studies** - Show all studies in Obsidian vault
6. **Archive study** - Move completed study to `4-archive/learning/`

## Progress Tracking

When user wants to mark progress:

1. Read current `main.md`
2. Find the section checkbox
3. Toggle `[ ]` to `[x]` (or vice versa)
4. Update `last_reviewed` date in frontmatter

## Example Usage

```
/choru-study ~/go/src/cdf/docs/study/go-context-study-plan.md
```

This will:
1. Read the file
2. Create `~/Desktop/choru/choru-notes/1-projects/learning/go-context/main.md`
3. Add progress checkboxes for each H2 section
4. Report success

## List All Studies

```bash
ls -la ~/Desktop/choru/choru-notes/1-projects/learning/
```

For each study, read `main.md` and count completed checkboxes:
```bash
grep -c "\[x\]" main.md  # completed
grep -c "\[ \]" main.md  # remaining
```

## Archiving

When a study is complete:
```bash
mv ~/Desktop/choru/choru-notes/1-projects/learning/topic-name ~/Desktop/choru/choru-notes/4-archive/learning/
```

## Important

- Always preserve original code blocks and formatting
- Use Obsidian-compatible markdown (wiki-links like `[[file]]`)
- Keep source file path in frontmatter for reference
- Don't modify the original source file
