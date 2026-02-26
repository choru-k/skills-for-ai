# Catalog Sync/Check Command Contract

This contract defines expected behavior for catalog-driven artifact generation commands.

## Command Interface (v1)

Primary command shape:

```bash
python3 scripts/sync-catalog-artifacts.py [--check]
```

Optional scope flags (if implemented):

```bash
python3 scripts/sync-catalog-artifacts.py [--check] --only marketplace,pi,skills-index
```

- Default mode: `sync` (mutating)
- Non-mutating mode: `--check`

## Managed Artifacts

- `.claude-plugin/marketplace.json`
- `package.json` (`pi.skills`, `pi.extensions` only)
- `skills/` plugin-backed symlink index

## Behavior Matrix

| Mode | Writes files | Removes stale generated entries | Reports drift | Exit on drift |
|------|--------------|----------------------------------|---------------|---------------|
| `sync` | yes | yes | optional summary | no |
| `check` | no | no | required | yes (non-zero) |

## Sync Contract (mutating)

1. Load and validate catalog.
2. Generate expected output for each managed artifact.
3. Apply deterministic writes only when content differs.
4. Remove stale generated entries no longer represented in catalog.
5. Print concise per-artifact summary.

### Idempotency
Running `sync` repeatedly with unchanged inputs must produce no further diffs.

## Check Contract (non-mutating)

1. Load and validate catalog.
2. Compute expected outputs exactly as `sync` does.
3. Compare expected vs current without writing.
4. Emit readable drift report.
5. Exit non-zero if drift exists.

## Drift Report Format

Minimum required report lines:

```text
DRIFT <artifact> <change-type> <identifier> <detail>
```

Examples:
- `DRIFT package.json pi.skills missing plugins/call-ai/skills/call-ai/SKILL.md`
- `DRIFT marketplace.json plugin stale cc-dev-hooks`
- `DRIFT skills-index symlink mismatch skills/pi-front-compaction`

## Error Handling Contract

Hard-fail (non-zero) when:
- catalog validation fails
- required files are missing/unreadable
- generated mapping has conflicts or ambiguity

The command must not partially write files in `check` mode.

## Determinism Requirements

- Use stable ordering by catalog `id`.
- Emit normalized POSIX relative paths.
- Emit stable JSON formatting for generated JSON artifacts.

## Implemented Guardrail Commands (Phase 4)

Current enforced command set:

```bash
python3 scripts/sync-catalog-artifacts.py --check --lane public
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
bash scripts/validate-contract-scenarios.sh
```

Local shortcuts:

```bash
just catalog-check
just drift-check
just private-leak-check
just contract-scenario-check
just skills-index-check
```

Contracts:
- `sync-catalog-artifacts.py --check --lane public` is the canonical non-mutating public-lane contract check.
- `check-public-output-drift.sh` is a wrapper around the canonical check and must fail non-zero on drift.
- `check-private-leaks.sh` must fail on private-ID leakage in public distribution outputs, including `npm pack --dry-run --json` artifact paths.
- `validate-contract-scenarios.sh` must prove reproducible detection for at least one drift and one private-leak negative scenario in isolated temp copies.
- `skills-index-check` remains a scoped non-mutating check over `skills/` symlink index (`--only skills-index`).

## Compatibility Notes

- `scripts/sync-skills-index.py` remains available as a legacy narrow utility.
- `scripts/sync-catalog-artifacts.py` is the canonical sync/check entrypoint for catalog-managed public artifacts.
