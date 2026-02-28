#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/test-runner-routing.sh"
bash "$SCRIPT_DIR/test-zellij-launch-options.sh"
bash "$SCRIPT_DIR/test-run-parallel.sh"

echo "All call-ai tests passed."
