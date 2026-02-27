# Catalog Sync/Check Command Contract

This contract defines expected behavior for catalog-driven artifact generation commands.

## Command Interface (v2, breaking)

Primary command shape:

```bash
python3 scripts/sync-catalog-artifacts.py [--check]
```

Optional scope flags:

```bash
python3 scripts/sync-catalog-artifacts.py [--check] --only marketplace,pi
```

- Default mode: `sync` (mutating)
- Non-mutating mode: `--check`

## Managed Artifacts

- `.claude-plugin/marketplace.json`
- `package.json` (`pi.skills`, `pi.extensions` only)

> Breaking change: `skills/` shared-index sync is no longer a managed output.

## Behavior Matrix

| Mode | Writes files | Reports drift | Exit on drift |
|------|--------------|---------------|---------------|
| `sync` | yes | optional summary | no |
| `check` | no | required | yes (non-zero) |

## Drift Report Format

Minimum required report lines:

```text
DRIFT <artifact> <change-type> <identifier> <detail>
```

Examples:
- `DRIFT package.json pi.skills index=0 current="..." expected="..."`
- `DRIFT .claude-plugin/marketplace.json plugins index=2 current={...} expected={...}`

## Determinism Requirements

- Use stable ordering by catalog `id`.
- Emit normalized POSIX relative paths.
- Emit stable JSON formatting for generated JSON artifacts.

## Human-First Source-of-Truth (breaking)

- Catalog paths are canonical under:
  - `common/*`
  - `claude/*`
  - `pi/*`
  - `pi/extensions/*`
- `package.json#pi.skills` / `pi.extensions` emit canonical paths.
- Marketplace records are resolved from canonical skill entries and plugin metadata (`plugins/*/.claude-plugin/plugin.json`), with source paths emitted as canonical skill roots.

## Legacy Bridge Retirement Contract

The following legacy compatibility surfaces are retired and must not exist:
- `skills/*`
- `plugins/*/skills/*`
- `plugins/*/pi/skills/*`
- `plugins/*/pi/extensions/*`

Guardrail command:

```bash
bash scripts/check-legacy-bridges.sh
```

## Guardrail Commands

```bash
just catalog-check
just legacy-bridge-check
just drift-check
just private-leak-check
just contract-scenario-check
```

## Failure Contracts

- `sync-catalog-artifacts.py --check --lane public` is the canonical non-mutating public-lane contract check.
- `check-public-output-drift.sh` wraps drift + legacy bridge retirement checks and fails non-zero on any violation.
- `check-private-leaks.sh` fails on private-ID leakage in public distribution outputs, including `npm pack --dry-run --json` artifact paths.
- `validate-contract-scenarios.sh` proves reproducible detection for drift, private-leak, and legacy-bridge negative scenarios.
