# Unified Sync/Check Contract

## Version
- Contract version: v2
- Status: Active
- Last updated: 2026-02-27

## Scope

Defines how sync/check commands generate and validate public distribution artifacts from lane-root source paths.

In scope:
- Source discovery rules
- Public output mapping rules
- Drift/leak validation expectations

Out of scope:
- Runtime loader behavior in external repos
- CI ownership/process policy

## Source model

There is no catalog manifest file.

Source discovery reads lane-root paths directly:
- `public/common/*`
- `public/claude/*`
- `public/pi/*`
- `private/common/*`
- `private/claude/*`
- `private/pi/*`

Discovery rules:
- Skills: `<lane>/<target>/<skill-id>/SKILL.md`
- Pi extensions: `<lane>/pi/extensions/*.{ts,js,mjs,cjs}` with `export default`

## Managed outputs

- `.claude-plugin/marketplace.json`
- `package.json` (`pi.skills`, `pi.extensions`)

## Sync semantics

- Sync is deterministic for unchanged inputs.
- Entries are ordered by discovered path.
- Public outputs include only `public/*` entries.
- Any `private/*` path in public outputs is a contract violation.

## Check semantics

- Check mode is non-mutating.
- Check fails on:
  - drift between generated artifacts and expected state
  - private leakage into public outputs
  - invalid source layout/input constraints

## Failure semantics

Normative mapping table: `docs/contracts/operator-failure-semantics.md`

## Operator commands

- `just catalog-sync` — sync public artifacts from lane-root discovery
- `just catalog-check` — non-mutating public contract check
- `just drift-check` — guardrail wrapper around public contract check
- `just private-leak-check` — fail on non-public path leakage into public outputs
- `just contract-scenario-check` — validate negative drift/leak/legacy scenarios
