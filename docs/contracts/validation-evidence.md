# Validation Evidence — Unified Sync/Check Contract

## Context
This file records reproducible validation evidence for Phase-1 item-4 (drift/leak validation and hardening).

Date: 2026-02-26

## Commands Run

```bash
just catalog-check
just drift-check
just private-leak-check
just contract-scenario-check
bash skills/skill-playbook/scripts/graph-qa.sh
```

## Results Summary

| Scenario | Command | Expected | Actual | Status |
|---|---|---|---|---|
| Baseline contract consistency | `just catalog-check` | no drift | `catalog artifacts are in sync` | pass |
| Baseline public guardrail | `just drift-check` | no drift | `public-output drift checks passed` | pass |
| Baseline private leak guardrail | `just private-leak-check` | no private leak | `private-leak checks passed` | pass |
| Negative drift simulation | `just contract-scenario-check` (scenario 2) | fail with drift signal | script validated expected non-zero + `DRIFT` output | pass |
| Negative private leak simulation | `just contract-scenario-check` (scenario 3) | fail leak check | script validated expected non-zero + leak signal | pass |
| Graph QA | `bash skills/skill-playbook/scripts/graph-qa.sh` | pass | `Graph QA passed` | pass |

## Residual Risks

1. **Private lane source-of-truth still external to this public repository**
   - Impact: lane contracts are validated here, but private-lane runtime behavior still depends on external/private wiring.
   - Follow-up: validate private-lane repository integration in the next cutover item.

2. **Catalog-to-marketplace eligibility for non-plugin common skills is intentionally skipped**
   - Impact: common skills under `skills/*` are Pi-facing, not emitted as marketplace plugins.
   - Follow-up: keep this rule explicit in contracts if generation policy changes.

3. **Scenario harness uses temporary repository copies**
   - Impact: higher runtime cost than direct checks.
   - Follow-up: optimize scenario harness if CI runtime becomes a concern.

## Reviewer/Tester Handoff Notes

- Contract check entrypoint: `scripts/sync-catalog-artifacts.py --check --lane public`
- Guardrail wrappers:
  - `scripts/check-public-output-drift.sh`
  - `scripts/check-private-leaks.sh`
  - `scripts/validate-contract-scenarios.sh`
- Exit code mapping is documented in `docs/contracts/operator-failure-semantics.md`.
