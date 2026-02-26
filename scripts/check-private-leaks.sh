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

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required to verify publish artifact private-leak policy" >&2
  exit 1
fi

PACK_JSON="$(mktemp)"
trap 'rm -f "${PACK_JSON}"' EXIT
npm pack --dry-run --json >"${PACK_JSON}"

python3 - "${PACK_JSON}" <<'PY'
import json
import sys
from pathlib import Path

pack_json = Path(sys.argv[1])
data = json.loads(pack_json.read_text(encoding="utf-8"))
if not isinstance(data, list) or not data:
    raise SystemExit("ERROR: npm pack --dry-run --json returned unexpected payload")

files = data[0].get("files")
if not isinstance(files, list):
    raise SystemExit("ERROR: npm pack payload missing files list")

paths = [entry.get("path") for entry in files if isinstance(entry, dict)]
private_prefixes = (
    "skills/choru-ticket/",
    "skills/work-lessons/",
    "skills/work-ticket/",
    "skills/work-workspace/",
)

leaks = [path for path in paths if isinstance(path, str) and path.startswith(private_prefixes)]
if leaks:
    preview = "\n".join(f"  - {path}" for path in leaks)
    raise SystemExit(f"ERROR: private paths leaked into npm pack output:\n{preview}")

print(f"validated npm pack private-leak policy: files={len(paths)}")
PY

echo "private-leak checks passed"
