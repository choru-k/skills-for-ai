#!/usr/bin/env python3
"""Private-leak guardrail for public distribution outputs."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_PREFIXES = ("private/",)


def fail(message: str, code: int = 1) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return code


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise RuntimeError(f"missing file: {path}") from None
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid JSON at {path}: {exc}") from exc


def validate_marketplace() -> None:
    marketplace = load_json(REPO_ROOT / ".claude-plugin" / "marketplace.json")
    plugins = marketplace.get("plugins")
    if not isinstance(plugins, list):
        raise RuntimeError("marketplace.json missing plugins array")

    for plugin in plugins:
        if not isinstance(plugin, dict):
            raise RuntimeError(f"invalid marketplace plugin entry: {plugin!r}")

        source = plugin.get("source")
        if not isinstance(source, str):
            raise RuntimeError(f"marketplace plugin source must be string: {plugin!r}")
        if not source.startswith("public/"):
            raise RuntimeError(f"non-public source leaked into marketplace.json: {source}")

    print(f"validated marketplace private-leak policy: plugins={len(plugins)}")


def validate_package() -> None:
    package = load_json(REPO_ROOT / "package.json")
    pi_payload = package.get("pi")
    if not isinstance(pi_payload, dict):
        raise RuntimeError("package.json missing pi object")

    for field in ("skills", "extensions"):
        values = pi_payload.get(field)
        if not isinstance(values, list):
            raise RuntimeError(f"package.json pi.{field} missing array")

        for raw in values:
            if not isinstance(raw, str):
                raise RuntimeError(f"non-string pi.{field} entry: {raw!r}")
            if not raw.startswith("public/"):
                raise RuntimeError(f"non-public path leaked in pi.{field} entry: {raw}")

        print(f"validated package private-leak policy: pi.{field} entries={len(values)}")


def validate_npm_pack() -> None:
    if shutil.which("npm") is None:
        raise RuntimeError("npm is required to verify publish artifact private-leak policy")

    proc = subprocess.run(
        ["npm", "pack", "--dry-run", "--json"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )

    if proc.stderr:
        # Keep npm warnings visible to operator logs.
        sys.stderr.write(proc.stderr)

    if proc.returncode != 0:
        raise RuntimeError(f"npm pack --dry-run --json failed with exit code {proc.returncode}")

    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"npm pack JSON payload is invalid: {exc}") from exc

    if not isinstance(data, list) or not data:
        raise RuntimeError("npm pack --dry-run --json returned unexpected payload")

    files = data[0].get("files") if isinstance(data[0], dict) else None
    if not isinstance(files, list):
        raise RuntimeError("npm pack payload missing files list")

    paths = [entry.get("path") for entry in files if isinstance(entry, dict)]
    leaks = [path for path in paths if isinstance(path, str) and path.startswith(FORBIDDEN_PREFIXES)]
    if leaks:
        preview = "\n".join(f"  - {path}" for path in leaks)
        raise RuntimeError(f"non-public paths leaked into npm pack output:\n{preview}")

    print(f"validated npm pack private-leak policy: files={len(paths)}")


def main() -> int:
    try:
        validate_marketplace()
        validate_package()
        validate_npm_pack()
    except RuntimeError as exc:
        return fail(str(exc))

    print("private-leak checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
