#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

python3 scripts/sync-skills-index.py --check

python3 - <<'PY'
import json
from pathlib import Path

root = Path.cwd()
package = json.loads((root / "package.json").read_text(encoding="utf-8"))
pi = package.get("pi", {})

skills = pi.get("skills")
extensions = pi.get("extensions")
if not isinstance(skills, list) or not isinstance(extensions, list):
    raise SystemExit("ERROR: package.json missing pi.skills/pi.extensions arrays")

for field, entries in (("pi.skills", skills), ("pi.extensions", extensions)):
    for raw in entries:
        if not isinstance(raw, str):
            raise SystemExit(f"ERROR: {field} entry must be string: {raw!r}")
        rel = Path(raw)
        if rel.is_absolute():
            raise SystemExit(f"ERROR: {field} path must be relative: {raw}")
        abs_path = root / rel
        if not abs_path.exists():
            raise SystemExit(f"ERROR: {field} path does not exist: {raw}")

print(f"validated package pi paths: skills={len(skills)} extensions={len(extensions)}")

marketplace = json.loads((root / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8"))
plugins = marketplace.get("plugins")
if not isinstance(plugins, list):
    raise SystemExit("ERROR: .claude-plugin/marketplace.json missing plugins array")

for idx, plugin in enumerate(plugins):
    if not isinstance(plugin, dict):
        raise SystemExit(f"ERROR: plugin entry must be object at index {idx}")
    name = plugin.get("name", f"index:{idx}")
    source = plugin.get("source")
    if not isinstance(source, str) or not source:
        raise SystemExit(f"ERROR: plugin {name} missing source")

    rel = Path(source)
    if rel.is_absolute():
        raise SystemExit(f"ERROR: plugin {name} source must be relative: {source}")

    source_path = root / rel
    if not source_path.is_dir():
        raise SystemExit(f"ERROR: plugin {name} source directory does not exist: {source}")

    plugin_json = source_path / ".claude-plugin" / "plugin.json"
    if not plugin_json.is_file():
        raise SystemExit(f"ERROR: plugin {name} missing plugin.json at {plugin_json.relative_to(root)}")

print(f"validated marketplace plugin sources: {len(plugins)}")
PY

echo "public-output drift checks passed"
