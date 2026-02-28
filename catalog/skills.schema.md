# Source Discovery Schema (v3)

This document defines the canonical source-discovery contract for public artifact generation.

## Source model

There is no `catalog/skills.yaml` manifest.

The source of truth is the lane-root filesystem layout:

- `public/common/*`
- `public/claude/*`
- `public/pi/*`
- `private/common/*`
- `private/claude/*`
- `private/pi/*`

## Discovery rules

### Skills
- Pattern: `<lane>/<target>/<skill-id>/SKILL.md`
- `lane` must be `public` or `private`
- `target` must be `common`, `claude`, or `pi`
- `skill-id` must be kebab-case (`^[a-z0-9][a-z0-9-]*$`)

### Pi extensions
- Pattern: `<lane>/pi/extensions/*.{ts,js,mjs,cjs}`
- Entry point requirement: file content includes `export default`
- Derived extension id = filename stem (kebab-case)

## Derived metadata

Metadata is inferred from discovered path:
- `lane` from segment 1
- `target` from segment 2
- `kind` (`skill` or `extension`) from path/file rule
- `id` from directory/file name

## Public-output rules

Only discovered entries under `public/*` are eligible for generated public artifacts.
Discovered entries under `private/*` are excluded from:

- `.claude-plugin/marketplace.json`
- `package.json#pi.skills`
- `package.json#pi.extensions`

## Determinism

Generators process discovered entries in deterministic `path` order (ascending POSIX paths).
