set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

# Install this repository as a local Pi package.
pi-install-local:
    pi install .

# Preview npm package contents and metadata before publish.
pi-pack-dry-run:
    npm pack --dry-run

# Sync all catalog-managed public artifacts.
catalog-sync:
    python3 scripts/sync-catalog-artifacts.py --lane public

# Check all catalog-managed public artifacts (non-mutating).
catalog-check:
    python3 scripts/sync-catalog-artifacts.py --check --lane public

# Guardrail: fail if legacy compatibility bridge paths exist.
legacy-bridge-check:
    bash scripts/check-legacy-bridges.sh

# CI/local guardrail: detect public-output drift.
drift-check:
    bash scripts/check-public-output-drift.sh

# CI/local guardrail: detect private-ID leakage into public outputs.
private-leak-check:
    bash scripts/check-private-leaks.sh

# Validate negative drift/leak/legacy scenarios in isolated temp copies.
contract-scenario-check:
    bash scripts/validate-contract-scenarios.sh
