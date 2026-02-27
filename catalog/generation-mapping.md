# Catalog Generation Mapping (v3)

Deterministic mapping from `catalog/skills.yaml` to public artifacts.

## Inputs

- Catalog entries (`id`, `visibility`, `target`, `kind`, `path`)
- Plugin metadata (`plugins/*/.claude-plugin/plugin.json`)

## Source path contract

Catalog paths are lane-rooted:
- `public/common/*`, `public/claude/*`, `public/pi/*`
- `private/common/*`, `private/claude/*`, `private/pi/*`

## Global rules

1. Sort entries by `id` ascending.
2. Public outputs include only `visibility: public`.
3. `visibility: private` entries are excluded from all public artifacts.
4. Mapping ambiguity is a hard error.

## `.claude-plugin/marketplace.json`

Eligibility:
- `visibility: public`
- `kind: skill`
- `target: claude` or `target: common`

Mapping:
- Match skill id to plugin metadata name (`cc-context-fork -> context-fork` override)
- Emit:
  - `name`
  - `description`
  - `source = dirname(path)` (lane-rooted, e.g. `public/common/call-ai`)

## `package.json#pi`

### `pi.skills`
Include when:
- `visibility: public`
- `kind: skill`
- `target: pi` or `target: common`

### `pi.extensions`
Include when:
- `visibility: public`
- `kind: extension`
- `target: pi`

Emit repository-relative POSIX paths from catalog.

## Private exclusion

Private paths/IDs must not appear in:
- `.claude-plugin/marketplace.json`
- `package.json#pi.skills`
- `package.json#pi.extensions`
- npm pack file list
