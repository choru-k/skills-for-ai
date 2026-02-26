# Operations Runbook

## Daily/PR Checks

Run from repository root:

```bash
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
bash skills/skill-playbook/scripts/graph-qa.sh
python3 scripts/sync-skills-index.py --check
```

Use these checks before opening/merging PRs that touch skills, manifests, catalog contracts, or workflow scripts.

## Release Checks

1. Execute all daily/PR checks.
2. Execute publish preflight/postflight flow in `catalog/publish-checklist.md`.
3. Validate package preview:

```bash
npm pack --dry-run
```

4. Publish only after pass gates are green.

## Incident Response

When any guardrail fails in CI or local release flow:

1. Stop release progression.
2. Capture failing command output.
3. Run rollback guide: `catalog/migration-rollback.md`.
4. Re-run:

```bash
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
python3 scripts/sync-skills-index.py --check
```

5. Confirm runtime gate status via `catalog/runtime-wiring-matrix.md` pass/fail criteria.

## Acceptance Command Set

The acceptance baseline for Phase 4 is:

```bash
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
bash skills/skill-playbook/scripts/graph-qa.sh
python3 scripts/sync-skills-index.py --check
npm pack --dry-run
```

Expected:
- all commands exit 0
- no private-ID leakage in public outputs
- no index/manifest drift
- package dry-run succeeds
