# Sync/Check Command Contract

Defines behavior for lane-root-driven public artifact generation.

## Command interface

```bash
python3 scripts/sync-catalog-artifacts.py [--check] [--only marketplace,pi]
```

- default: sync (mutating)
- `--check`: non-mutating drift mode

## Managed artifacts

- `.claude-plugin/marketplace.json`
- `package.json` (`pi.skills`, `pi.extensions`)

## Lane-root source contract

Source discovery reads canonical lane-rooted paths:
- `public/common/*`
- `public/claude/*`
- `public/pi/*`
- `private/common/*`
- `private/claude/*`
- `private/pi/*`

Public outputs use only discovered `public/*` paths.

## Legacy retirement contract

These paths must not exist:
- `skills/*`
- `common/*`, `claude/*`, `pi/*` (pre-lane roots)
- `plugins/*/skills/*`
- `plugins/*/pi/skills/*`
- `plugins/*/pi/extensions/*`

Guardrail:

```bash
bash scripts/check-legacy-bridges.sh
```

## Drift output format

```text
DRIFT <artifact> <field> index=<n> current=<...> expected=<...>
```

## Guardrails

```bash
just catalog-check
just legacy-bridge-check
just drift-check
just private-leak-check
just contract-scenario-check
```
