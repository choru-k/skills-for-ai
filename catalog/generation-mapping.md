# Catalog Generation Mapping (v2)

This document defines deterministic mapping from catalog entries to public distribution artifacts.

## Inputs

- Canonical catalog entries (`catalog/skills.yaml`)
- Plugin metadata (`plugins/*/.claude-plugin/plugin.json`) for marketplace name/description
- Package metadata (`package.json`) for `pi` payload shape

## Global Rules

1. Process entries sorted by `id` ascending.
2. Public outputs consume only `visibility: public` entries.
3. `visibility: private` entries are excluded from all public outputs.
4. Any mapping ambiguity is a hard error.

## Mapping to `.claude-plugin/marketplace.json`

### Eligibility
An entry is eligible for Claude marketplace mapping when:
- `visibility: public`
- `kind: skill`
- `target: claude` or `target: common`
- entry maps to a known plugin metadata name

### Plugin metadata resolution
- Read all plugin metadata from `plugins/*/.claude-plugin/plugin.json`.
- Match eligible skill IDs to plugin names:
  - default: `plugin_name = skill_id`
  - override map: `cc-context-fork -> context-fork`

### Emitted plugin record
For each matched skill/plugin pair, emit:
- `name`: plugin metadata `name`
- `description`: plugin metadata `description`
- `source`: canonical skill root (`dirname(path)`), e.g. `common/call-ai`, `claude/cc-dev-hooks`

### De-duplication and ordering
- One record per plugin name.
- Sort output plugins by `name` ascending.

### Conflict handling
Fail mapping when:
- plugin metadata file is missing/invalid
- same plugin name resolves to conflicting metadata or source values

## Mapping to `package.json#pi`

### `pi.skills`
Include entry `path` when:
- `visibility: public`
- `kind: skill`
- `target: pi` or `target: common`

### `pi.extensions`
Include entry `path` when:
- `visibility: public`
- `kind: extension`
- `target: pi`

### Ordering
- Sort by entry `id` ascending.
- Emit normalized POSIX repository-relative paths.

## Private exclusion rule

Private entries (`visibility: private`) must never be emitted into:
- `.claude-plugin/marketplace.json`
- `package.json#pi.skills`
- `package.json#pi.extensions`

Any private ID in public outputs is a contract violation.
