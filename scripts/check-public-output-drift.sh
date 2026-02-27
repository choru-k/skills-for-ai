#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

bash scripts/check-legacy-bridges.sh
python3 scripts/sync-catalog-artifacts.py --check --lane public

echo "public-output drift checks passed"
