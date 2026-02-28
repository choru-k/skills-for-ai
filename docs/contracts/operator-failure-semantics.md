# Operator Failure Semantics

| Condition | Exit Code | Operator Output Pattern |
|---|---:|---|
| lane-mismatch | 2 | `ERROR: lane-mismatch: this repository manages public distribution artifacts only` |
| missing-generated-file | 3 | `ERROR: missing-generated-file: ...` |
| drift-detected | 4 | `DRIFT <artifact> <field> ...` |
| private-leak-in-public | 5 | `ERROR: private-leak-in-public: ...` |
| invalid-contract-input | 6 | `ERROR: invalid-contract-input: ...` |
