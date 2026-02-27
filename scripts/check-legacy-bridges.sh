#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

legacy_paths=()

shopt -s nullglob

# Legacy shared-index root is retired.
for path in skills skills/*; do
  [[ -e "${path}" ]] && legacy_paths+=("${path}")
done

# Legacy plugin bridge roots are retired.
for path in plugins/*/skills plugins/*/skills/* plugins/*/*/skills plugins/*/*/skills/*; do
  [[ -e "${path}" ]] && legacy_paths+=("${path}")
done
for path in plugins/*/pi/skills plugins/*/pi/skills/*; do
  [[ -e "${path}" ]] && legacy_paths+=("${path}")
done
for path in plugins/*/pi/extensions plugins/*/pi/extensions/*; do
  [[ -e "${path}" ]] && legacy_paths+=("${path}")
done

shopt -u nullglob

if [[ ${#legacy_paths[@]} -gt 0 ]]; then
  echo "ERROR: legacy compatibility bridge paths detected:" >&2
  for path in "${legacy_paths[@]}"; do
    if [[ -L "${path}" ]]; then
      target="$(readlink "${path}")"
      echo "  - ${path} -> ${target}" >&2
    else
      echo "  - ${path}" >&2
    fi
  done
  exit 1
fi

echo "legacy bridge retirement check passed"
