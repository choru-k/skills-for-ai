#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

python3 - <<'PY'
import json
from pathlib import Path

root = Path.cwd()

marketplace = json.loads((root / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8"))
plugins = marketplace.get("plugins")
if not isinstance(plugins, list):
    raise SystemExit("ERROR: marketplace.json missing plugins array")

for plugin in plugins:
    if not isinstance(plugin, dict):
        raise SystemExit(f"ERROR: invalid marketplace plugin entry: {plugin!r}")
    source = plugin.get("source")
    if not isinstance(source, str):
        raise SystemExit(f"ERROR: marketplace plugin source must be string: {plugin!r}")
    if not source.startswith("public/"):
        raise SystemExit(f"ERROR: non-public source leaked into marketplace.json: {source}")

print(f"validated marketplace private-leak policy: plugins={len(plugins)}")

package = json.loads((root / "package.json").read_text(encoding="utf-8"))
pi = package.get("pi")
if not isinstance(pi, dict):
    raise SystemExit("ERROR: package.json missing pi object")

for field in ("skills", "extensions"):
    values = pi.get(field)
    if not isinstance(values, list):
        raise SystemExit(f"ERROR: package.json pi.{field} missing array")

    for raw in values:
        if not isinstance(raw, str):
            raise SystemExit(f"ERROR: non-string pi.{field} entry: {raw!r}")
        if not raw.startswith("public/"):
            raise SystemExit(f"ERROR: non-public path leaked in pi.{field} entry: {raw}")

    print(f"validated package private-leak policy: pi.{field} entries={len(values)}")
PY

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
forbidden_prefixes = (
    "private/",
)

leaks = [path for path in paths if isinstance(path, str) and path.startswith(forbidden_prefixes)]
if leaks:
    preview = "\n".join(f"  - {path}" for path in leaks)
    raise SystemExit(f"ERROR: non-public paths leaked into npm pack output:\n{preview}")

print(f"validated npm pack private-leak policy: files={len(paths)}")
PY

echo "private-leak checks passed"
