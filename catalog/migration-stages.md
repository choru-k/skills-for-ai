# Migration Stages (Phase 2)

## Public Output Deltas

### `.claude-plugin/marketplace.json`
- Expected delta: no plugin removals required for this phase, but enforce explicit check that private IDs/paths never appear.
- Compatibility note: unchanged plugin entries are acceptable if they reference only public plugin roots.

### `package.json#pi.skills`
- Expected delta: remove private skill paths:
  - `skills/choru-ticket/SKILL.md`
  - `skills/work-lessons/SKILL.md`
  - `skills/work-ticket/SKILL.md`
  - `skills/work-workspace/SKILL.md`
- Keep public/common and pi-target public skills intact.

### `skills/` generated index
- Expected delta: ensure public repo index no longer includes private skill entries post-cutover.
- Keep plugin-backed public symlink entries and public shared directories intact.

## Stage Plan

### Stage 1: Prepare private lane and mapping freeze
- Preconditions:
  - `catalog/private-boundary-decision.md` approved.
  - `catalog/private-skill-placement.md` approved.
  - `catalog/migration-map.md` validated.
- Steps:
  1. Ensure private repository checkout exists with mirrored paths for private skills.
  2. Freeze private-skill IDs/targets (`visibility: private`, `target: common`).
  3. Capture baseline public outputs for diffing.
- Deliverable:
  - Ready-to-migrate private lane with no public-output changes yet.

### Stage 2: Apply public-output deltas
- Preconditions:
  - Stage 1 complete.
  - Local runtime continuity bridge available for private skills.
- Steps:
  1. Remove private skill paths from `package.json#pi.skills`.
  2. Regenerate/sync `skills/` index and verify no private entries in public lane.
  3. Validate `.claude-plugin/marketplace.json` has no private references.
- Deliverable:
  - Public outputs reflect public-only lane semantics.

### Stage 3: Cut over source-of-truth and validate
- Preconditions:
  - Stage 2 validation gates pass.
  - Rollback checklist is ready (item-4).
- Steps:
  1. Move private skill source-of-truth to private repository lane.
  2. Confirm local runtime links resolve private skills from private lane.
  3. Re-run drift and leak checks.
- Deliverable:
  - Private/public repository boundary enforced in practice.

## Preconditions

1. Catalog inventory is current (`catalog/skills.yaml`).
2. Boundary and placement contracts are approved.
3. Baseline snapshots for public manifests are captured.
4. Runtime owners agree on temporary compatibility bridges.

## Stop Points

Stop and review before continuing if:

1. Private IDs appear in public artifacts during Stage 2.
2. Private-skill local runtime resolution fails after Stage 3 cutover.
3. Generated index/manifests show unexpected non-deterministic drift.
4. Migration introduces unresolved alias/path breakage.

## Validation Gates

- **Gate A (after Stage 1):** mapping and placement docs are internally consistent.
- **Gate B (after Stage 2):** public outputs have no private IDs/paths and pass sync/check validation.
- **Gate C (after Stage 3):** local runtime can load private skills from private lane and public outputs remain clean.

Suggested checks:

```bash
python3 scripts/sync-skills-index.py --check
rg -n "choru-ticket|work-lessons|work-ticket|work-workspace" .claude-plugin/marketplace.json package.json skills
rg -n "visibility: private" catalog/skills.yaml
```
