# Phase 1 Acceptance and Migration Handoff

This document is the Phase 1 handoff contract for `2026-02-25-skills-public-private-target-model`.

## Phase 1 Outputs

- `catalog/skills.schema.md`
- `catalog/skills.example.yaml`
- `catalog/schema-validation.md`
- `catalog/generation-mapping.md`
- `catalog/command-contract.md`

These files are the canonical contract baseline for later implementation phases.

## Acceptance Checklist

### Schema and Metadata
- [ ] Required fields are defined (`id`, `visibility`, `target`, `path`, `kind`).
- [ ] Enum sets are explicit (`public|private`, `claude|pi|common`, `skill|extension`).
- [ ] Metadata authority is explicit; naming prefixes are non-authoritative convention.

### Mapping Rules
- [ ] Mapping to `.claude-plugin/marketplace.json` is deterministic and conflict-defined.
- [ ] Mapping to `package.json#pi.skills` and `package.json#pi.extensions` is deterministic.
- [ ] Ordering and deduplication behavior are specified.

### Sync/Check Behavior
- [ ] Mutating `sync` behavior and stale cleanup rules are specified.
- [ ] Non-mutating `check` behavior and drift exit rules are specified.
- [ ] Drift output format is specified for troubleshooting.

### Leak Prevention
- [ ] Private entries are excluded from all public outputs by explicit rule.
- [ ] Leak detection is fail-closed and blocks publish.

## Inputs/Outputs for Phase 2

## Inputs
Phase 2 must consume:
- the catalog schema + validation contracts
- the generation mapping contract
- the sync/check command contract

## Outputs
Phase 2 must produce:
- concrete inventory classification for current skills/extensions
- public/private repository-lane migration plan with sequencing
- rollback-ready migration steps for private skills (`choru-ticket`, `work-*`)

## Compatibility Policy

1. **No immediate runtime breakage**
   - Existing Claude/Pi wiring remains valid until migration cutover is complete.

2. **Compatibility aliases remain during migration**
   - Existing command aliases (for example front-compaction Pi aliases) remain supported until explicit deprecation plan is accepted.

3. **Manifest compatibility window**
   - During migration, generated outputs may support compatibility entries if documented and deterministic.

## Rollback Contract

If Phase 2/3 migration causes regressions:

1. Restore previous generated manifests and symlink indexes from git.
2. Re-run current stable sync flow (`scripts/sync-catalog-artifacts.py --lane public`) to restore known-good artifact state.
3. Re-enable compatibility outputs before retrying migration.
4. Log root cause and mitigation in plan artifacts before next attempt.

## Open Decisions Carried Forward

- Final physical repo boundary for private skills (same repo private lane vs separate private repository).
- Exact publish gating workflow once full catalog-driven generation is implemented.
- Whether non-plugin public `common` skills should be marketplace-addressable or Pi-only by policy.
