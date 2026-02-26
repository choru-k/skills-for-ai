# Catalog Generation Mapping (v1)

This document defines deterministic mapping from catalog entries to public distribution artifacts.

## Inputs

- Canonical catalog entries defined by `catalog/skills.schema.md`
- Source metadata:
  - plugin metadata at `plugins/<plugin>/.claude-plugin/plugin.json`
  - package metadata at root `package.json`

## Global Rules

1. Process entries sorted by `id` (ascending) for deterministic outputs.
2. Public outputs consume only `visibility: public` entries.
3. `visibility: private` entries are excluded from all public outputs.
4. Any mapping ambiguity is a hard error (no silent fallback).

## Mapping to `.claude-plugin/marketplace.json`

### Eligibility
An entry is eligible for Claude marketplace mapping when:
- `visibility: public`
- `kind: skill`
- `target: claude` or `target: common`

### Source Resolution
- Eligible entries MUST have `path` under `plugins/<plugin-name>/...`.
- Resolve plugin root as `plugins/<plugin-name>`.
- Read plugin metadata from `plugins/<plugin-name>/.claude-plugin/plugin.json`.

### Emitted Plugin Record
For each unique plugin root, emit one record:
- `name`: plugin metadata name
- `description`: plugin metadata description
- `source`: `plugins/<plugin-name>`

### De-duplication and Ordering
- Multiple eligible skills from the same plugin collapse into one plugin record.
- Sort output plugins by `name` ascending.

### Conflict Handling
Fail mapping when:
- plugin metadata file is missing/invalid
- same plugin `name` resolves to different `source` values
- eligible entry is not under `plugins/` (unmappable for Claude marketplace)

## Mapping to `package.json#pi`

### `pi.skills`
Include entry `path` in `pi.skills` when:
- `visibility: public`
- `kind: skill`
- `target: pi` or `target: common`

### `pi.extensions`
Include entry `path` in `pi.extensions` when:
- `visibility: public`
- `kind: extension`
- `target: pi` or `target: common`

### Ordering and De-duplication
- Sort `pi.skills` and `pi.extensions` by entry `id` ascending.
- Emit normalized POSIX relative paths.
- Duplicate emitted paths are a hard error.

### Conflict Handling
Fail mapping when:
- any emitted path does not exist
- emitted path is outside repository root
- an entry qualifies for both `pi.skills` and `pi.extensions`

## Private Entry Exclusion Rule

Private entries (`visibility: private`) are never emitted into:
- `.claude-plugin/marketplace.json`
- `package.json#pi.skills`
- `package.json#pi.extensions`

Any private ID found in public outputs is a contract violation.

## Example Mapping Matrix

| id | visibility | kind | target | public Claude output | public Pi output |
|----|------------|------|--------|----------------------|------------------|
| `cc-front-compaction` | public | skill | claude | included via plugin record | excluded |
| `pi-front-compaction` | public | skill | pi | excluded | included in `pi.skills` |
| `call-ai` | public | skill | common | included via plugin record | included in `pi.skills` |
| `work-ticket` | private | skill | common | excluded | excluded |
| `front-compaction-extension` | public | extension | pi | excluded | included in `pi.extensions` |
