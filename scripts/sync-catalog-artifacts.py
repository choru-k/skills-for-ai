#!/usr/bin/env python3
"""Sync/check public distribution artifacts from lane-root source paths.

Managed artifacts:
- package.json (pi.skills, pi.extensions)
- .claude-plugin/marketplace.json (plugins list)

Exit codes:
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

LANE_MISMATCH = 2
MISSING_GENERATED_FILE = 3
DRIFT_DETECTED = 4
PRIVATE_LEAK_IN_PUBLIC = 5
INVALID_CONTRACT_INPUT = 6

REPO_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_FILE = REPO_ROOT / "package.json"
MARKETPLACE_FILE = REPO_ROOT / ".claude-plugin" / "marketplace.json"
PLUGINS_DIR = REPO_ROOT / "plugins"

VALID_LANES = ("public", "private")
VALID_TARGETS = ("common", "claude", "pi")
VALID_EXTENSION_SUFFIXES = {".ts", ".js", ".mjs", ".cjs"}
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
EXTENSION_ENTRYPOINT_PATTERN = re.compile(r"\bexport\s+default\b")
SKILL_PLUGIN_NAME_OVERRIDES = {
    "cc-context-fork": "context-fork",
}


@dataclass(frozen=True)
class CatalogEntry:
    id: str
    lane: str
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


def validate_entry_id(entry_id: str, path: str) -> None:
    if not ID_PATTERN.match(entry_id):
        raise ContractError(
            f"invalid-contract-input: derived id '{entry_id}' is not kebab-case for path: {path}"
        )


def discover_skill_entries() -> list[CatalogEntry]:
    entries: list[CatalogEntry] = []

    for lane in VALID_LANES:
        for target in VALID_TARGETS:
            root = REPO_ROOT / lane / target
            if not root.is_dir():
                continue

            for child in sorted(root.iterdir(), key=lambda item: item.name):
                if not child.is_dir():
                    continue

                skill_file = child / "SKILL.md"
                if not skill_file.is_file():
                    continue

                path = rel(skill_file)
                entry_id = child.name
                validate_entry_id(entry_id, path)

                entries.append(
                    CatalogEntry(
                        id=entry_id,
                        lane=lane,
                        target=target,
                        kind="skill",
                        path=path,
                    )
                )

    return entries


def discover_extension_entries() -> list[CatalogEntry]:
    entries: list[CatalogEntry] = []

    for lane in VALID_LANES:
        extensions_root = REPO_ROOT / lane / "pi" / "extensions"
        if not extensions_root.is_dir():
            continue

        for file in sorted(extensions_root.iterdir(), key=lambda item: item.name):
            if not file.is_file():
                continue
            if file.suffix not in VALID_EXTENSION_SUFFIXES:
                continue

            path = rel(file)

            try:
                source = file.read_text(encoding="utf-8")
            except UnicodeDecodeError as exc:
                raise ContractError(
                    f"invalid-contract-input: extension source must be UTF-8 text ({path}: {exc})"
                ) from exc

            if not EXTENSION_ENTRYPOINT_PATTERN.search(source):
                # Helper modules under extensions/ are allowed but are not runtime entrypoints.
                continue

            entry_id = file.stem
            validate_entry_id(entry_id, path)

            entries.append(
                CatalogEntry(
                    id=entry_id,
                    lane=lane,
                    target="pi",
                    kind="extension",
                    path=path,
                )
            )

    return entries


def load_catalog_entries() -> list[CatalogEntry]:
    entries = discover_skill_entries() + discover_extension_entries()

    if not entries:
        raise ContractError(
            "invalid-contract-input: no lane-root entries discovered under public/private",
        )

    seen_paths: set[str] = set()
    for entry in entries:
        if entry.path in seen_paths:
            raise ContractError(f"invalid-contract-input: duplicate discovered path: {entry.path}")
        seen_paths.add(entry.path)

    return sorted(entries, key=lambda entry: entry.path)


def expected_pi_lists(entries: list[CatalogEntry]) -> tuple[list[str], list[str]]:
    skill_paths: list[str] = []
    extension_paths: list[str] = []

    for entry in entries:
        if entry.lane != "public":
            continue

        if entry.kind == "skill" and entry.target in {"pi", "common"}:
            skill_paths.append(entry.path)
        if entry.kind == "extension" and entry.target == "pi":
            extension_paths.append(entry.path)

    leaked_paths = [path for path in skill_paths + extension_paths if path.startswith("private/")]
    if leaked_paths:
        preview = ", ".join(sorted(leaked_paths))
        raise ContractError(
            f"private-leak-in-public: private path emitted to package.json pi payloads: {preview}",
            PRIVATE_LEAK_IN_PUBLIC,
        )

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
        if entry.lane != "public" or entry.kind != "skill" or entry.target not in {"claude", "common"}:
            continue

        plugin_name = SKILL_PLUGIN_NAME_OVERRIDES.get(entry.id, entry.id)
        plugin_meta = plugin_meta_index.get(plugin_name)
        if not plugin_meta:
            # Skill may be intentionally non-plugin-managed for marketplace.
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

    leaked_sources = [plugin["source"] for plugin in plugins if plugin["source"].startswith("private/")]
    if leaked_sources:
        preview = ", ".join(sorted(leaked_sources))
        raise ContractError(
            f"private-leak-in-public: private source emitted to marketplace: {preview}",
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
    parser = argparse.ArgumentParser(description="Sync/check managed artifacts")
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
