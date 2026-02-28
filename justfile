set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

# Install this repository as a local Pi package.
pi-install-local:
    pi install .

# Preview npm package contents and metadata before publish.
pi-pack-dry-run:
    npm pack --dry-run

# Sync all lane-root-discovered public artifacts.
catalog-sync:
    python3 scripts/sync-catalog-artifacts.py --lane public

# Check all lane-root-discovered public artifacts (non-mutating).
catalog-check:
    python3 scripts/sync-catalog-artifacts.py --check --lane public

# CI/local guardrail: detect public-output drift.
drift-check:
    python3 scripts/check-public-output-drift.py

# CI/local guardrail: detect non-public path leakage into public outputs.
private-leak-check:
    python3 scripts/check-private-leaks.py

# Validate negative drift/leak scenarios in isolated temp copies.
contract-scenario-check:
    python3 scripts/validate-contract-scenarios.py
