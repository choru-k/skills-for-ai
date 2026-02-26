# Unified Sync/Check Acceptance Matrix

| ID | Lane | Scenario | Input State | Expected Check Result | Expected Sync Result |
|---|---|---|---|---|---|
| P01 | public | clean public sync/check | canonical public inputs present | pass | no-op |
| P02 | private | clean private sync/check | canonical private+public inputs present | pass | no-op |
| P03 | public | recover from missing generated file | generated artifact missing | fail (missing-generated-file) | regenerate public artifact |
| P04 | private | recover from drift | generated artifact stale | fail (drift-detected) | regenerate private artifact |
| N01 | public | private leak detected in public output | private token appears in public artifact | fail (private-leak-in-public) | blocked until source corrected |
| N02 | private | lane metadata mismatch | artifact lane metadata = public | fail (lane-mismatch) | blocked until lane corrected |
| N03 | public | invalid input metadata | contract metadata incomplete | fail (invalid-contract-input) | blocked |
| N04 | private | check run against wrong lane target | lane flag and target path diverge | fail (lane-mismatch) | blocked |
