# Operator Failure Semantics

| Condition | Exit Code | Operator Output |
|---|---:|---|
| lane-mismatch | 2 | ERROR: lane mismatch between requested lane and artifact lane metadata |
| missing-generated-file | 3 | ERROR: expected generated artifact missing; run sync for active lane |
| drift-detected | 4 | ERROR: generated artifact drift detected against canonical inputs |
| private-leak-in-public | 5 | ERROR: private content detected in public lane output |
| invalid-contract-input | 6 | ERROR: contract input metadata is invalid or incomplete |
