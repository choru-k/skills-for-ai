# Generation Mapping (v5, lane-root discovery)

Deterministic mapping from lane-root sources to public artifacts.

## Inputs

- Discovered lane-root sources under:
  - `public/common/*`, `public/claude/*`, `public/pi/*`
  - `private/common/*`, `private/claude/*`, `private/pi/*`
- Plugin metadata (`plugins/*/.claude-plugin/plugin.json`)

## Discovery rules

- Skills: `<lane>/<target>/<skill-id>/SKILL.md`
- Pi extensions (entrypoints): `<lane>/pi/extensions/*.{ts,js,mjs,cjs}` containing `export default`

Derived metadata:
- `lane` from path segment 1
- `target` from path segment 2
- `kind` from path/file pattern
- `id` from skill directory name or extension filename stem

## Global rules

1. Sort discovered entries by `path` ascending.
2. Public outputs include only `lane = public` entries.
3. Any `private/*` path in public outputs is a hard failure.
4. Mapping ambiguity is a hard error.

## `.claude-plugin/marketplace.json`

Eligibility:
- lane = `public`
- kind = `skill`
- target = `claude` or `common`

Mapping:
- Match derived skill id to plugin metadata name (`cc-context-fork -> context-fork` override)
- Emit:
  - `name`
  - `description`
  - `source = dirname(path)` (for example `public/common/call-ai`)

## `package.json#pi`

### `pi.skills`
Include when:
- lane = `public`
- kind = `skill`
- target = `pi` or `common`

### `pi.extensions`
Include when:
- lane = `public`
- kind = `extension`
- target = `pi`

Emit repository-relative POSIX paths.

## Private exclusion

Private paths must not appear in:
- `.claude-plugin/marketplace.json`
- `package.json#pi.skills`
- `package.json#pi.extensions`
- npm pack file list
