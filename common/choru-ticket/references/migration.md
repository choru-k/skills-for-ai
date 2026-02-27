# Legacy Migration Guide (Personal Projects)

Use this when old personal project folders store plan files directly in project root.

## Legacy Markers

A project likely needs migration when root contains:
- `task-*.md`
- `phase-*.md`
- `main.md` with `tier: small|medium|big`

## Safety Rules

1. Preview files before moving
2. Ask user confirmation
3. Move only plan files, not general notes
4. Ensure project root has a hub `main.md` after migration

## Single-Project Migration Steps

Assume:
- `PROJECT_DIR=~/Desktop/choru/choru-notes/1-projects/personal/<project-name>`
- `PLAN_SLUG=legacy-import`
- `DATE=$(date +%Y-%m-%d)`
- `PLAN_DIR="$PROJECT_DIR/plans/$DATE-$PLAN_SLUG"`

### 1) Create destination

```bash
mkdir -p "$PROJECT_DIR/plans" "$PROJECT_DIR/notes" "$PLAN_DIR"
```

### 2) Preview candidate files

```bash
find "$PROJECT_DIR" -maxdepth 1 -type f \( -name 'task-*.md' -o -name 'phase-*.md' -o -name 'main.md' \)
```

### 3) Move task/phase files

```bash
for f in "$PROJECT_DIR"/task-*.md "$PROJECT_DIR"/phase-*.md; do
  [ -e "$f" ] || continue
  mv "$f" "$PLAN_DIR"/
done
```

### 4) Move root main.md only if it is plan-style

```bash
if [ -f "$PROJECT_DIR/main.md" ] && rg -n '^tier:\s*(small|medium|big)$' "$PROJECT_DIR/main.md" >/dev/null; then
  mv "$PROJECT_DIR/main.md" "$PLAN_DIR/main.md"
fi
```

### 5) Ensure project hub main.md exists

If project root `main.md` is missing after step 4, create a project-hub `main.md` and link:
- `[[plans/<DATE>-<PLAN_SLUG>/main|<DATE>-<PLAN_SLUG>]]`

## Bulk Migration Scan

Find candidate project folders:

```bash
for d in ~/Desktop/choru/choru-notes/1-projects/personal/*; do
  [ -d "$d" ] || continue
  if find "$d" -maxdepth 1 -type f \( -name 'task-*.md' -o -name 'phase-*.md' \) | grep -q .; then
    echo "$d"
  fi
done
```

Then run single-project migration per confirmed folder.

## Post-Migration Checklist

- [ ] `plans/` exists
- [ ] legacy plan files moved under a dated plan folder
- [ ] root `main.md` is project hub (not plan file)
- [ ] project hub links migrated plan
- [ ] no data loss (spot-check moved files)
