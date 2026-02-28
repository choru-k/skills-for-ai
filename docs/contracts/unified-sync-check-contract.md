# Unified Sync/Check Contract

## Version
- Contract version: v1
- Status: Draft for ratification
- Last updated: 2026-02-26

## Terminology
- **Lane**: public or private generation/check context.
- **Sync**: generation/update workflow for lane outputs.
- **Check**: validation workflow that enforces contract compliance.
- **Drift**: generated outputs differ from canonical source inputs.
- **Canonical input**: source artifact(s) that define expected generated outputs.

## Scope Boundaries

### In scope
- Canonical sync/check behavior definitions.
- Lane-aware validation expectations.
- Operator-visible failure semantics references.

### Out of scope
- Implementation code changes.
- CI wiring changes.
- Runtime loader refactors.

## Lane Model
- **Public lane**: includes only public artifacts approved for distribution.
- **Private lane**: includes private artifacts and local-only compatibility wiring.
- **Common target artifacts**: may be shared by both lanes, but policy and leak guards remain lane-specific.

## Inputs
- Lane-root source discovery under `public/*` and `private/*`.
- Mapping and policy contracts under `catalog/*.md`.
- Existing generated artifacts for drift comparison.

## Outputs
- Lane-aware sync/check expectations for generated artifacts, including:
  - `.claude-plugin/marketplace.json`
  - `package.json` (`pi.skills`, `pi.extensions`)
  - shared `skills/` index state

## Sync Semantics
- Sync MUST generate lane outputs from canonical source inputs only.
- Public lane MUST exclude private-only content and private identifiers.
- Private lane MAY include public + private content but MUST preserve lane markers and boundaries.
- Sync SHOULD be deterministic for unchanged canonical inputs.

## Check Semantics
- Check MUST fail on any lane leakage or artifact drift.
- Check MUST compare generated artifacts to canonical expectations for the active lane.
- Check MUST return deterministic pass/fail outcomes for unchanged inputs.
- Check MUST remain non-mutating in check mode.

## Failure Semantics
- Contract violations map to explicit exit codes and operator-facing messages.
- Failures MUST clearly identify condition class (lane mismatch, drift, missing artifact, invalid input, leak).
- The normative mapping table is defined in `operator-failure-semantics.md`.

## Operator Commands
- `just catalog-sync` — sync public catalog-managed artifacts.
- `just catalog-check` — non-mutating public contract check.
- `just drift-check` — guardrail wrapper around public contract checks.
- `just private-leak-check` — fail on private ID leakage into public outputs.

## Non-Goals
- Defining implementation-level script internals.
- Defining CI workflow ownership details.
- Executing migration/cutover changes directly.
