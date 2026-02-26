#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

PRIVATE_IDS_REGEX='choru-ticket|work-lessons|work-ticket|work-workspace'
PRIVATE_SKILL_PATHS_REGEX='skills/(choru-ticket|work-lessons|work-ticket|work-workspace)/SKILL\.md'

if rg -n "${PRIVATE_IDS_REGEX}" .claude-plugin/marketplace.json; then
  echo "ERROR: private IDs leaked into .claude-plugin/marketplace.json" >&2
  exit 1
fi

if rg -n "${PRIVATE_SKILL_PATHS_REGEX}" package.json; then
  echo "ERROR: private skill paths leaked into package.json#pi.skills" >&2
  exit 1
fi

python3 - <<'PY'
import json
from pathlib import Path

root = Path.cwd()
package = json.loads((root / "package.json").read_text(encoding="utf-8"))
skills = package.get("pi", {}).get("skills", [])
private_ids = {"choru-ticket", "work-lessons", "work-ticket", "work-workspace"}

for raw in skills:
    if not isinstance(raw, str):
        raise SystemExit(f"ERROR: non-string pi.skills entry: {raw!r}")
    for pid in private_ids:
        if pid in raw:
            raise SystemExit(f"ERROR: private ID leaked in pi.skills entry: {raw}")

print(f"validated pi.skills private-leak policy: {len(skills)} entries")
PY

while IFS= read -r link; do
  name="$(basename "$link")"
  case "${name}" in
    choru-ticket|work-lessons|work-ticket|work-workspace)
      echo "ERROR: private ID leaked as plugin-backed shared-index symlink: skills/${name}" >&2
      exit 1
      ;;
  esac
done < <(find skills -maxdepth 1 -type l | sort)

# Keep denylist aligned with catalog private assertions.
rg -n "id: (choru-ticket|work-lessons|work-ticket|work-workspace)|visibility: private" catalog/skills.yaml >/dev/null

echo "private-leak checks passed"
