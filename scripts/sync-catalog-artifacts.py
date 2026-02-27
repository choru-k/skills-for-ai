#!/usr/bin/env python3
"""Sync/check catalog-managed public artifacts.

Managed artifacts:
- package.json (pi.skills, pi.extensions)
- .claude-plugin/marketplace.json (plugins list)

Exit codes (aligned with docs/contracts/operator-failure-semantics.md):
- 2: lane-mismatch
- 3: missing-generated-file
- 4: drift-detected
- 5: private-leak-in-public
- 6: invalid-contract-input
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except Exception as exc:  # pragma: no cover - dependency guard
    print(f"ERROR: invalid-contract-input: PyYAML is required ({exc})", file=sys.stderr)
    raise SystemExit(6)

LANE_MISMATCH = 2
MISSING_GENERATED_FILE = 3
DRIFT_DETECTED = 4
PRIVATE_LEAK_IN_PUBLIC = 5
INVALID_CONTRACT_INPUT = 6

REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_FILE = REPO_ROOT / "catalog" / "skills.yaml"
PACKAGE_FILE = REPO_ROOT / "package.json"
MARKETPLACE_FILE = REPO_ROOT / ".claude-plugin" / "marketplace.json"
PLUGINS_DIR = REPO_ROOT / "plugins"

VALID_VISIBILITY = {"public", "private"}
VALID_TARGET = {"claude", "pi", "common"}
VALID_KIND = {"skill", "extension"}
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
PRIVATE_IDS = {"choru-ticket", "work-lessons", "work-ticket", "work-workspace"}
SKILL_PLUGIN_NAME_OVERRIDES = {
    "cc-context-fork": "context-fork",
}


@dataclass(frozen=True)
class CatalogEntry:
    id: str
    visibility: str
    target: str
    kind: str
    path: str


class ContractError(RuntimeError):
    def __init__(self, message: str, code: int = INVALID_CONTRACT_INPUT):
        super().__init__(message)
        self.code = code


def rel(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def load_json(path: Path) -> Any:
    if not path.is_file():
        raise ContractError(f"missing-generated-file: missing {rel(path)}", MISSING_GENERATED_FILE)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ContractError(f"invalid-contract-input: invalid JSON at {rel(path)} ({exc})") from exc


def save_json(path: Path, payload: Any) -> None:
    path.write_text(f"{json.dumps(payload, indent=2, ensure_ascii=False)}\n", encoding="utf-8")


def load_catalog_entries() -> list[CatalogEntry]:
    if not CATALOG_FILE.is_file():
        raise ContractError(f"missing-generated-file: missing {rel(CATALOG_FILE)}", MISSING_GENERATED_FILE)

    try:
        data = yaml.safe_load(CATALOG_FILE.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ContractError(f"invalid-contract-input: invalid YAML at {rel(CATALOG_FILE)} ({exc})") from exc

    if not isinstance(data, dict):
        raise ContractError("invalid-contract-input: catalog root must be an object")

    entries = data.get("entries")
    if not isinstance(entries, list):
        raise ContractError("invalid-contract-input: catalog missing entries array")

    seen_ids: set[str] = set()
    result: list[CatalogEntry] = []

    for index, raw in enumerate(entries):
        if not isinstance(raw, dict):
            raise ContractError(f"invalid-contract-input: entry[{index}] must be an object")

        for field in ("id", "visibility", "target", "kind", "path"):
            if field not in raw:
                raise ContractError(f"invalid-contract-input: entry[{index}] missing field '{field}'")

        entry_id = raw["id"]
        visibility = raw["visibility"]
        target = raw["target"]
        kind = raw["kind"]
        path = raw["path"]

        if not isinstance(entry_id, str) or not ID_PATTERN.match(entry_id):
            raise ContractError(f"invalid-contract-input: invalid id '{entry_id}'")
        if entry_id in seen_ids:
            raise ContractError(f"invalid-contract-input: duplicate id '{entry_id}'")
        seen_ids.add(entry_id)

        if visibility not in VALID_VISIBILITY:
            raise ContractError(f"invalid-contract-input: invalid visibility '{visibility}' for id '{entry_id}'")
        if target not in VALID_TARGET:
            raise ContractError(f"invalid-contract-input: invalid target '{target}' for id '{entry_id}'")
        if kind not in VALID_KIND:
            raise ContractError(f"invalid-contract-input: invalid kind '{kind}' for id '{entry_id}'")
        if not isinstance(path, str):
            raise ContractError(f"invalid-contract-input: path must be string for id '{entry_id}'")

        path_obj = Path(path)
        if path_obj.is_absolute() or path.startswith("./"):
            raise ContractError(f"invalid-contract-input: path must be repository-relative for id '{entry_id}'")

        path_parts = path_obj.parts
        if len(path_parts) < 3:
            raise ContractError(f"invalid-contract-input: path must use lane-root layout for id '{entry_id}': {path}")

        lane = path_parts[0]
        path_target = path_parts[1]
        if lane not in {"public", "private"}:
            raise ContractError(f"invalid-contract-input: path lane must be public/private for id '{entry_id}': {path}")
        if path_target not in VALID_TARGET:
            raise ContractError(f"invalid-contract-input: path target must be common/claude/pi for id '{entry_id}': {path}")
        if visibility != lane:
            raise ContractError(
                f"invalid-contract-input: visibility/path lane mismatch for id '{entry_id}' ({visibility} vs {lane})"
            )
        if target != path_target:
            raise ContractError(f"invalid-contract-input: target/path mismatch for id '{entry_id}' ({target} vs {path_target})")

        abs_path = REPO_ROOT / path_obj
        if not abs_path.exists():
            raise ContractError(f"invalid-contract-input: path does not exist for id '{entry_id}': {path}")

        if kind == "skill" and not path.endswith("SKILL.md"):
            raise ContractError(f"invalid-contract-input: skill path must end with SKILL.md for id '{entry_id}'")

        if target in {"claude", "common"} and kind == "extension":
            raise ContractError(f"invalid-contract-input: extensions are only supported for target=pi (id '{entry_id}')")

        result.append(
            CatalogEntry(
                id=entry_id,
                visibility=visibility,
                target=target,
                kind=kind,
                path=path,
            )
        )

    return sorted(result, key=lambda entry: entry.id)


def expected_pi_lists(entries: list[CatalogEntry]) -> tuple[list[str], list[str]]:
    skill_paths: list[str] = []
    extension_paths: list[str] = []

    for entry in entries:
        if entry.visibility != "public":
            continue
        if entry.kind == "skill" and entry.target in {"pi", "common"}:
            skill_paths.append(entry.path)
        if entry.kind == "extension" and entry.target in {"pi", "common"}:
            extension_paths.append(entry.path)

    if any(any(pid in path for pid in PRIVATE_IDS) for path in skill_paths):
        raise ContractError("private-leak-in-public: private skill path emitted to pi.skills", PRIVATE_LEAK_IN_PUBLIC)

    return skill_paths, extension_paths


def load_plugin_metadata_index() -> dict[str, dict[str, str]]:
    mapping: dict[str, dict[str, str]] = {}

    for plugin_json in sorted(PLUGINS_DIR.glob("*/.claude-plugin/plugin.json")):
        data = load_json(plugin_json)

        name = data.get("name")
        description = data.get("description")
        if not isinstance(name, str) or not name:
            raise ContractError(f"invalid-contract-input: plugin name missing at {rel(plugin_json)}")
        if not isinstance(description, str):
            raise ContractError(f"invalid-contract-input: plugin description missing at {rel(plugin_json)}")

        existing = mapping.get(name)
        candidate = {
            "name": name,
            "description": description,
        }
        if existing and existing != candidate:
            raise ContractError(f"invalid-contract-input: conflicting plugin metadata for name '{name}'")
        mapping[name] = candidate

    return mapping


def expected_marketplace_plugins(entries: list[CatalogEntry]) -> list[dict[str, str]]:
    plugin_meta_index = load_plugin_metadata_index()
    plugin_records: dict[str, dict[str, str]] = {}

    for entry in entries:
        if entry.visibility != "public" or entry.kind != "skill" or entry.target not in {"claude", "common"}:
            continue

        plugin_name = SKILL_PLUGIN_NAME_OVERRIDES.get(entry.id, entry.id)
        plugin_meta = plugin_meta_index.get(plugin_name)
        if not plugin_meta:
            # skill may be intentionally non-plugin-managed for marketplace.
            continue

        source = Path(entry.path).parent.as_posix()
        candidate = {
            "name": plugin_meta["name"],
            "description": plugin_meta["description"],
            "source": source,
        }

        existing = plugin_records.get(plugin_name)
        if existing and existing != candidate:
            raise ContractError(f"invalid-contract-input: conflicting marketplace source for plugin '{plugin_name}'")
        plugin_records[plugin_name] = candidate

    plugins = sorted(plugin_records.values(), key=lambda plugin: plugin["name"])

    leak_names = [plugin["name"] for plugin in plugins if plugin["name"] in PRIVATE_IDS]
    if leak_names:
        raise ContractError(
            f"private-leak-in-public: private plugin IDs emitted to marketplace: {', '.join(sorted(leak_names))}",
            PRIVATE_LEAK_IN_PUBLIC,
        )

    return plugins


def compare_list(current: list[Any], expected: list[Any], artifact: str, field: str) -> list[str]:
    if current == expected:
        return []

    lines: list[str] = []
    max_len = max(len(current), len(expected))
    for index in range(max_len):
        current_value = current[index] if index < len(current) else "<missing>"
        expected_value = expected[index] if index < len(expected) else "<missing>"
        if current_value != expected_value:
            lines.append(
                f"DRIFT {artifact} {field} index={index} current={json.dumps(current_value)} expected={json.dumps(expected_value)}"
            )
    return lines


def run(args: argparse.Namespace) -> int:
    if args.lane != "public":
        raise ContractError(
            "lane-mismatch: this repository manages public distribution artifacts only",
            LANE_MISMATCH,
        )

    entries = load_catalog_entries()

    enabled = set(args.only.split(",")) if args.only else {"pi", "marketplace"}
    valid_enabled = {"pi", "marketplace"}
    invalid = sorted(enabled - valid_enabled)
    if invalid:
        raise ContractError(f"invalid-contract-input: unsupported --only target(s): {', '.join(invalid)}")

    package = load_json(PACKAGE_FILE)
    if not isinstance(package, dict):
        raise ContractError("invalid-contract-input: package.json root must be an object")
    pi_payload = package.get("pi")
    if not isinstance(pi_payload, dict):
        raise ContractError("invalid-contract-input: package.json missing object field pi")

    expected_pi_skills, expected_pi_extensions = expected_pi_lists(entries)

    drift_lines: list[str] = []

    if "pi" in enabled:
        current_skills = pi_payload.get("skills")
        current_extensions = pi_payload.get("extensions")
        if not isinstance(current_skills, list) or not isinstance(current_extensions, list):
            raise ContractError("invalid-contract-input: package.json missing pi.skills/pi.extensions arrays")

        drift_lines.extend(compare_list(current_skills, expected_pi_skills, "package.json", "pi.skills"))
        drift_lines.extend(compare_list(current_extensions, expected_pi_extensions, "package.json", "pi.extensions"))

    marketplace = load_json(MARKETPLACE_FILE)
    if not isinstance(marketplace, dict):
        raise ContractError("invalid-contract-input: marketplace.json root must be an object")

    expected_plugins = expected_marketplace_plugins(entries)

    if "marketplace" in enabled:
        current_plugins = marketplace.get("plugins")
        if not isinstance(current_plugins, list):
            raise ContractError("invalid-contract-input: marketplace.json missing plugins array")
        drift_lines.extend(compare_list(current_plugins, expected_plugins, ".claude-plugin/marketplace.json", "plugins"))

    if drift_lines and args.check:
        for line in drift_lines:
            print(line)
        return DRIFT_DETECTED

    if args.check:
        print("catalog artifacts are in sync")
        return 0

    if "pi" in enabled:
        pi_payload["skills"] = expected_pi_skills
        pi_payload["extensions"] = expected_pi_extensions
        package["pi"] = pi_payload
        save_json(PACKAGE_FILE, package)
        print("synced package.json pi.skills/pi.extensions")

    if "marketplace" in enabled:
        marketplace["plugins"] = expected_plugins
        save_json(MARKETPLACE_FILE, marketplace)
        print("synced .claude-plugin/marketplace.json plugins")

    print("catalog artifact sync complete")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sync/check catalog-managed artifacts")
    parser.add_argument("--check", action="store_true", help="Do not modify files; fail on drift")
    parser.add_argument(
        "--lane",
        default="public",
        choices=["public", "private"],
        help="Lane context to validate (public supported in this repository)",
    )
    parser.add_argument(
        "--only",
        help="Comma-separated subset: pi,marketplace",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return run(args)
    except ContractError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return exc.code


if __name__ == "__main__":
    raise SystemExit(main())
