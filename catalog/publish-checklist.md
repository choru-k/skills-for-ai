# Publish Checklist

## Preconditions

1. Working tree is clean or intentionally staged.
2. Phase 3 runtime wiring is complete (`catalog/runtime-wiring-matrix.md`).
3. Required tooling is available: `python3`, `bash`, `rg`, `npm`.

## Preflight

Run from repository root:

```bash
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
bash common/skill-playbook/scripts/graph-qa.sh
```

Expected:
- drift checks pass
- private-leak checks pass
- graph QA passes

## Publish Steps

1. Verify package contents:

```bash
npm pack --dry-run
```

2. Publish package (when release is approved):

```bash
npm publish
```

3. If Claude plugin metadata changed, confirm marketplace/plugin metadata references remain valid.

## Postflight

Re-run critical checks:

```bash
bash scripts/check-public-output-drift.sh
bash scripts/check-private-leaks.sh
```

Runtime guard checks:

```bash
rg -n "Skill\(cc-front-compaction\)" /Users/cheol/dotfiles/claude/settings.json
! rg -n "front-compaction-claude" /Users/cheol/dotfiles/claude/settings.json
rg -n '"skills"' /Users/cheol/dotfiles/pi/settings.json
```

## Contract References

- Runtime wiring gates: `catalog/runtime-wiring-matrix.md`
- Migration verification checklist: `catalog/migration-verification-checklist.md`
- Rollback runbook: `catalog/migration-rollback.md`
- Canonical wrapper names: `cc-front-compaction`, `pi-front-compaction`

## Publish Pass/Fail Gates

### Pass
Proceed only if all are true:
1. Preflight and postflight checks pass with no drift/leak errors.
2. `npm pack --dry-run` succeeds and package contents are expected.
3. Runtime guard checks preserve canonical wrapper naming.
4. No unresolved issues in verification or rollback references.

### Fail
Stop immediately if any are true:
1. Drift check fails (`check-public-output-drift.sh`).
2. Private-leak check fails (`check-private-leaks.sh`).
3. Runtime check shows missing canonical wrapper names or lane regressions.
4. Publish artifacts differ from expectations and cannot be explained.
