# Validation Evidence — Unified Sync/Check Contract

## Context
Reproducible validation evidence after lane-root discovery cutover (no catalog manifest).

Date: 2026-02-27

## Commands Run

```bash
just catalog-check
just drift-check
just private-leak-check
just contract-scenario-check
bash public/common/skill-playbook/scripts/graph-qa.sh
```

## Results Summary

| Scenario | Command | Expected | Actual | Status |
|---|---|---|---|---|
| Baseline contract consistency | `just catalog-check` | no drift | `catalog artifacts are in sync` | pass |
| Baseline public guardrail | `just drift-check` | no drift | `public-output drift checks passed` | pass |
| Baseline private leak guardrail | `just private-leak-check` | no non-public paths in public outputs | `private-leak checks passed` | pass |
| Negative drift simulation | `just contract-scenario-check` (scenario 2) | fail with drift signal | script validated expected non-zero + `DRIFT` output | pass |
| Negative private leak simulation | `just contract-scenario-check` (scenario 3) | fail leak check | script validated expected non-zero + leak signal | pass |
| Graph QA | `bash public/common/skill-playbook/scripts/graph-qa.sh` | pass | `Graph QA passed` | pass |

## Residual Risks

1. **Scenario harness runtime cost**
   - Impact: negative scenarios use temporary repository copies.
   - Follow-up: optimize only if CI duration becomes a blocker.

2. **Command naming legacy**
   - Impact: `catalog-*` command names remain for compatibility even though discovery is lane-root based.
   - Follow-up: optional rename in a dedicated compatibility-breaking cleanup.

## Reviewer/Tester Handoff Notes

- Contract check entrypoint: `scripts/sync-catalog-artifacts.py --check --lane public`
- Guardrail wrappers:
  - `scripts/check-public-output-drift.sh`
  - `scripts/check-private-leaks.sh`
  - `scripts/validate-contract-scenarios.sh`
- Exit code mapping: `docs/contracts/operator-failure-semantics.md`
