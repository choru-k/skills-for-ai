# CLAUDE.md

Guidance for working in this repository.

## Layout

Canonical source-of-truth is lane-rooted:

- `public/common/*`
- `public/claude/*`
- `public/pi/*`
- `private/common/*`
- `private/claude/*`
- `private/pi/*`

Legacy root compatibility paths are not supported.

## Key files

- `scripts/sync-catalog-artifacts.py`: sync/check public artifacts from lane-root paths
- `scripts/check-public-output-drift.sh`: drift guard wrapper
- `scripts/check-private-leaks.sh`: private leak guard
- `public/common/call-ai/ai-registry.yaml`: call-ai registry

## Public/private semantics

- `private/*` in this public repo is a lane contract, not access control.
- Public outputs must not include paths under `private/*`.

## Guardrail flow

```bash
just catalog-check
just drift-check
just private-leak-check
bash public/common/skill-playbook/scripts/graph-qa.sh
just contract-scenario-check
just pi-pack-dry-run
```

## Adding/updating entries

1. Update skill or extension sources in lane-root paths.
2. Run `just catalog-sync` then guardrail flow above.
