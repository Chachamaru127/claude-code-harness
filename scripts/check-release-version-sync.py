#!/usr/bin/env python3
"""Check release version consistency across plugin release surfaces."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CANONICAL_PRIORITY = [
    "VERSION",
    "package.json",
    ".claude-plugin/plugin.json",
    ".codex-plugin/plugin.json",
    ".cursor-plugin/plugin.json",
]


@dataclass
class Surface:
    name: str
    path: str
    pointer: str | None
    status: str
    version: str | None = None
    detail: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "path": self.path,
            "pointer": self.pointer,
            "status": self.status,
            "version": self.version,
            "detail": self.detail,
        }


def read_json(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON: {exc}"
    except OSError as exc:
        return None, f"read failed: {exc}"

    if not isinstance(data, dict):
        return None, "top-level JSON value must be an object"
    return data, None


def string_value(data: dict[str, Any], key: str) -> tuple[str | None, str | None]:
    value = data.get(key)
    if value is None:
        return None, f"missing .{key}"
    if not isinstance(value, str) or value.strip() == "":
        return None, f".{key} must be a non-empty string"
    return value.strip(), None


def add_json_version_surface(
    surfaces: list[Surface],
    root: Path,
    relative_path: str,
    name: str,
    pointer: str,
    *,
    required_when_file_exists: bool,
) -> dict[str, Any] | None:
    path = root / relative_path
    if not path.exists():
        surfaces.append(
            Surface(
                name=name,
                path=relative_path,
                pointer=pointer,
                status="skipped",
                detail="file not found",
            )
        )
        return None

    data, error = read_json(path)
    if error is not None or data is None:
        surfaces.append(
            Surface(
                name=name,
                path=relative_path,
                pointer=pointer,
                status="invalid",
                detail=error,
            )
        )
        return None

    version, version_error = string_value(data, "version")
    if version_error is not None:
        surfaces.append(
            Surface(
                name=name,
                path=relative_path,
                pointer=pointer,
                status="missing" if required_when_file_exists else "skipped",
                detail=version_error,
            )
        )
    else:
        surfaces.append(
            Surface(
                name=name,
                path=relative_path,
                pointer=pointer,
                status="present",
                version=version,
            )
        )

    return data


def collect_surfaces(root: Path) -> list[Surface]:
    surfaces: list[Surface] = []

    version_path = root / "VERSION"
    if version_path.exists():
        version = version_path.read_text(encoding="utf-8").strip()
        if version:
            surfaces.append(
                Surface(
                    name="VERSION",
                    path="VERSION",
                    pointer=None,
                    status="present",
                    version=version,
                )
            )
        else:
            surfaces.append(
                Surface(
                    name="VERSION",
                    path="VERSION",
                    pointer=None,
                    status="invalid",
                    detail="VERSION must be non-empty",
                )
            )
    else:
        surfaces.append(
            Surface(
                name="VERSION",
                path="VERSION",
                pointer=None,
                status="skipped",
                detail="file not found",
            )
        )

    add_json_version_surface(
        surfaces,
        root,
        "package.json",
        "package.json",
        "/version",
        required_when_file_exists=True,
    )
    add_json_version_surface(
        surfaces,
        root,
        ".claude-plugin/plugin.json",
        ".claude-plugin/plugin.json",
        "/version",
        required_when_file_exists=True,
    )
    add_json_version_surface(
        surfaces,
        root,
        ".codex-plugin/plugin.json",
        ".codex-plugin/plugin.json",
        "/version",
        required_when_file_exists=True,
    )
    add_json_version_surface(
        surfaces,
        root,
        ".cursor-plugin/plugin.json",
        ".cursor-plugin/plugin.json",
        "/version",
        required_when_file_exists=True,
    )

    marketplace_path = root / ".claude-plugin/marketplace.json"
    if not marketplace_path.exists():
        surfaces.append(
            Surface(
                name=".claude-plugin/marketplace.json metadata.version",
                path=".claude-plugin/marketplace.json",
                pointer="/metadata/version",
                status="skipped",
                detail="file not found",
            )
        )
        surfaces.append(
            Surface(
                name=".claude-plugin/marketplace.json plugins[]",
                path=".claude-plugin/marketplace.json",
                pointer="/plugins",
                status="skipped",
                detail="file not found",
            )
        )
        return surfaces

    marketplace, marketplace_error = read_json(marketplace_path)
    if marketplace_error is not None or marketplace is None:
        for name, pointer in [
            (".claude-plugin/marketplace.json metadata.version", "/metadata/version"),
            (".claude-plugin/marketplace.json plugins[]", "/plugins"),
        ]:
            surfaces.append(
                Surface(
                    name=name,
                    path=".claude-plugin/marketplace.json",
                    pointer=pointer,
                    status="invalid",
                    detail=marketplace_error,
                )
            )
        return surfaces

    metadata = marketplace.get("metadata")
    if not isinstance(metadata, dict):
        surfaces.append(
            Surface(
                name=".claude-plugin/marketplace.json metadata.version",
                path=".claude-plugin/marketplace.json",
                pointer="/metadata/version",
                status="missing",
                detail="missing .metadata.version",
            )
        )
    else:
        metadata_version = metadata.get("version")
        if not isinstance(metadata_version, str) or metadata_version.strip() == "":
            surfaces.append(
                Surface(
                    name=".claude-plugin/marketplace.json metadata.version",
                    path=".claude-plugin/marketplace.json",
                    pointer="/metadata/version",
                    status="missing",
                    detail=".metadata.version must be a non-empty string",
                )
            )
        else:
            surfaces.append(
                Surface(
                    name=".claude-plugin/marketplace.json metadata.version",
                    path=".claude-plugin/marketplace.json",
                    pointer="/metadata/version",
                    status="present",
                    version=metadata_version.strip(),
                )
            )

    plugins = marketplace.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        surfaces.append(
            Surface(
                name=".claude-plugin/marketplace.json plugins[]",
                path=".claude-plugin/marketplace.json",
                pointer="/plugins",
                status="missing",
                detail=".plugins must be a non-empty array",
            )
        )
        return surfaces

    for index, plugin in enumerate(plugins):
        plugin_name = None
        if isinstance(plugin, dict):
            value = plugin.get("name")
            if isinstance(value, str) and value.strip():
                plugin_name = value.strip()
        surface_name = (
            f".claude-plugin/marketplace.json plugins[{index}].version"
            if plugin_name is None
            else f".claude-plugin/marketplace.json plugins[{index}]({plugin_name}).version"
        )
        pointer = f"/plugins/{index}/version"

        if not isinstance(plugin, dict):
            surfaces.append(
                Surface(
                    name=surface_name,
                    path=".claude-plugin/marketplace.json",
                    pointer=pointer,
                    status="invalid",
                    detail="plugin entry must be an object",
                )
            )
            continue

        plugin_version = plugin.get("version")
        if not isinstance(plugin_version, str) or plugin_version.strip() == "":
            surfaces.append(
                Surface(
                    name=surface_name,
                    path=".claude-plugin/marketplace.json",
                    pointer=pointer,
                    status="missing",
                    detail=".plugins[].version must be a non-empty string",
                )
            )
        else:
            surfaces.append(
                Surface(
                    name=surface_name,
                    path=".claude-plugin/marketplace.json",
                    pointer=pointer,
                    status="present",
                    version=plugin_version.strip(),
                )
            )

    return surfaces


def choose_canonical(surfaces: list[Surface]) -> Surface | None:
    by_name = {surface.name: surface for surface in surfaces}
    for name in CANONICAL_PRIORITY:
        surface = by_name.get(name)
        if surface is not None and surface.status == "present" and surface.version:
            return surface
    return None


def build_report(root: Path) -> dict[str, Any]:
    surfaces = collect_surfaces(root)
    canonical = choose_canonical(surfaces)
    issues: list[dict[str, Any]] = []

    if canonical is None:
        issues.append(
            {
                "surface": "canonical",
                "status": "missing",
                "detail": f"No canonical version found. Expected {', '.join(CANONICAL_PRIORITY)}.",
            }
        )
    else:
        for surface in surfaces:
            if surface.status == "skipped":
                continue
            if surface.status != "present":
                issues.append(
                    {
                        "surface": surface.name,
                        "status": surface.status,
                        "detail": surface.detail,
                    }
                )
                continue
            if surface.version != canonical.version:
                issues.append(
                    {
                        "surface": surface.name,
                        "status": "mismatch",
                        "version": surface.version,
                        "expected": canonical.version,
                        "canonical_surface": canonical.name,
                    }
                )

    return {
        "ok": not issues,
        "root": str(root),
        "canonical_priority": CANONICAL_PRIORITY,
        "canonical": None if canonical is None else canonical.to_dict(),
        "surfaces": [surface.to_dict() for surface in surfaces],
        "issues": issues,
    }


def print_human(report: dict[str, Any]) -> None:
    priority = " > ".join(report["canonical_priority"])
    canonical = report["canonical"]
    if canonical is None:
        print(f"[FAIL] release version sync: no canonical version ({priority})")
    else:
        print(
            "[PASS]" if report["ok"] else "[FAIL]",
            f"release version sync: canonical {canonical['version']} from {canonical['name']} (priority: {priority})",
        )

    for surface in report["surfaces"]:
        status = surface["status"]
        name = surface["name"]
        version = surface["version"]
        detail = surface["detail"]
        if status == "present":
            if canonical is not None and version != canonical["version"]:
                print(f"  - MISMATCH {name}: {version} (expected {canonical['version']})")
            else:
                print(f"  - OK {name}: {version}")
        elif status == "skipped":
            print(f"  - SKIP {name}: {detail}")
        else:
            print(f"  - {status.upper()} {name}: {detail}")

    if report["issues"]:
        print("Tag/release is blocked until version surfaces are aligned.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check VERSION/package/plugin/marketplace release version sync."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Project root to inspect (default: current directory).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print structured JSON report.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"error: root not found: {root}", file=sys.stderr)
        return 2

    report = build_report(root)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_human(report)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
