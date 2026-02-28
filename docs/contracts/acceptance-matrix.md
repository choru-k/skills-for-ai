# Unified Sync/Check Acceptance Matrix

| ID | Scenario | Input State | Expected Check Result | Expected Sync Result |
|---|---|---|---|---|
| P01 | clean public sync/check | canonical lane-root sources present | pass | no-op |
| P02 | private sources present, correctly excluded | `private/*` skills exist with valid layout | pass | no private paths emitted |
| P03 | recover from missing generated file | generated artifact missing | fail (`missing-generated-file`) | regenerate public artifact |
| P04 | recover from drift | generated artifact stale | fail (`drift-detected`) | regenerate public artifact |
| N01 | private leak detected in public output | non-public path appears in public artifact | fail (`private-leak-in-public`) | blocked until source corrected |
| N02 | unsupported lane requested | command run with `--lane private` | fail (`lane-mismatch`) | blocked |
| N03 | invalid source layout | malformed lane-root source path/layout | fail (`invalid-contract-input`) | blocked |
| N04 | legacy bridge path reintroduced | retired compatibility path exists | fail (legacy bridge guardrail) | blocked |
