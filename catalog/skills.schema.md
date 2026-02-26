# Skills Catalog Schema

This document defines the canonical metadata contract for generated Claude/Pi manifests and local runtime indexes.

## Required Fields

Each catalog entry MUST include the following fields:

### id
- Type: `string`
- Purpose: stable entry identifier used across generated outputs.
- Constraints:
  - unique across the entire catalog
  - lowercase kebab-case: `^[a-z0-9][a-z0-9-]*$`

### visibility
- Type: `string`
- Purpose: publication and distribution boundary.
- Constraints: MUST be one of `public` or `private`.

### target
- Type: `string`
- Purpose: runtime lane selection.
- Constraints: MUST be one of `claude`, `pi`, or `common`.

### path
- Type: `string`
- Purpose: repository-relative source path for the artifact.
- Constraints:
  - MUST be a relative path from repository root
  - MUST NOT start with `/` or `./`
  - MUST resolve to an existing file

### kind
- Type: `string`
- Purpose: artifact class for mapping rules.
- Constraints: MUST be one of `skill` or `extension`.

## Enum Values

### visibility
- `public`: eligible for public distribution outputs.
- `private`: local/private lane only; never emitted to public outputs.

### target
- `claude`: Claude runtime/distribution lane only.
- `pi`: Pi runtime/distribution lane only.
- `common`: shared lane; eligible for both runtimes when visibility permits.

### kind
- `skill`: skill instruction artifact (`SKILL.md`).
- `extension`: runtime extension artifact (for example Pi TypeScript extension files).

## Validation Rules

1. **Field completeness**
   - `id`, `visibility`, `target`, `path`, and `kind` are all required.

2. **Enum validity**
   - `visibility`, `target`, and `kind` MUST use allowed enum values only.

3. **ID uniqueness**
   - Each `id` MUST be unique in the full catalog.

4. **Path validity**
   - `path` MUST be relative, must exist, and must not escape repository root.

5. **Kind/path consistency**
   - If `kind = skill`, `path` MUST end with `SKILL.md`.
   - If `kind = extension`, `path` MUST reference an extension source file.

6. **Target/kind consistency (v1)**
   - `target = claude` supports `kind = skill` only.
   - `target = common` supports `kind = skill` only.
   - `target = pi` supports `kind = skill` and `kind = extension`.

7. **Visibility guardrail**
   - `visibility = private` entries MUST be excluded from public outputs.

8. **Normalization for deterministic generation**
   - Generators should process entries sorted by `id`.
   - Path strings should be normalized to POSIX separators.

## Authority and Naming

Prefix naming (`cc-*`, `pi-*`) is a convention for readability and lifecycle hints.
Catalog metadata (`visibility`, `target`, `kind`) is authoritative for generation and policy decisions.
