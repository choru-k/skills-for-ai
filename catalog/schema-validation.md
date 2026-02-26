# Catalog Validation Contract

This document defines validation behavior required before catalog data can drive generated manifests and indexes.

## Required Checks

1. **Required fields present**
   - Reject entries missing `id`, `visibility`, `target`, `path`, or `kind`.

2. **Enum validation**
   - Reject unknown values for `visibility`, `target`, or `kind`.

3. **ID uniqueness**
   - Reject duplicate `id` values.

4. **Path checks**
   - `path` must be repository-relative and must exist.
   - Reject paths that escape repository root.

5. **Kind/path checks**
   - `skill` entries must point to `SKILL.md`.
   - `extension` entries must point to extension source files.

6. **Target compatibility checks**
   - Reject invalid target/kind combinations per `catalog/skills.schema.md`.

## Public Output Filters

When generating public outputs (`.claude-plugin/marketplace.json`, `package.json#pi`, shared public indexes):

- Entries with `visibility: private` are excluded from public outputs.
- `target: claude` contributes only to Claude lane outputs.
- `target: pi` contributes only to Pi lane outputs.
- `target: common` contributes to both lanes when visibility allows.

Filtering must be applied before sort/emit steps so private entries never appear in intermediate public artifacts.

## Drift Detection Contract

### sync mode (mutating)
- Writes generated outputs deterministically.
- Removes stale generated entries no longer present in catalog.
- Must be safe to run repeatedly (`sync` is idempotent).

### check mode (non-mutating)
- Performs the same computation as `sync` but does not write files.
- Returns non-zero exit when drift is detected.
- Emits readable per-file drift summary (missing, stale, mismatched entries).

## Leak Prevention Rules

1. **Fail-closed visibility**
   - Unknown or missing visibility values are treated as invalid and hard-fail validation.

2. **Private exclusion assertions**
   - Validation must assert that no private IDs appear in public output sets.

3. **Path boundary guard**
   - Private catalog paths must never be rewritten into public output records.

4. **Publish gate requirement**
   - Public publish workflows must run `check` and fail on any detected leak.

## Acceptance Checklist

- [ ] Validation rejects invalid enums and missing required fields.
- [ ] Validation rejects duplicate IDs.
- [ ] Validation rejects invalid paths and target/kind mismatches.
- [ ] Public outputs prove private entries are excluded.
- [ ] `sync` behavior is deterministic and idempotent.
- [ ] `check` behavior is non-mutating and exits non-zero on drift/leak.
