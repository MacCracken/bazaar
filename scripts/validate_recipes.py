#!/usr/bin/env python3
"""Validate bazaar recipe TOMLs.

Runs on CI and locally. Exits non-zero on any error; warnings don't fail.

Usage:
    scripts/validate_recipes.py                    # all recipes
    scripts/validate_recipes.py recipes/ai/x.toml  # specific files
    scripts/validate_recipes.py --zugot ../zugot   # also check deps against zugot

"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tomllib

REQUIRED_PACKAGE_FIELDS = ("name", "version", "description", "license", "groups")
REQUIRED_SECTIONS = ("package", "source", "depends", "build")
KNOWN_CATEGORIES = {
    "ai", "desktops", "editors", "games", "media",
    "networking", "security", "tools",
}


def collect_zugot_packages(zugot_root: pathlib.Path) -> set[str]:
    """Parse every .cyml under zugot and return the set of provided package names."""
    names: set[str] = set()
    for cyml in zugot_root.rglob("*.cyml"):
        try:
            with cyml.open("rb") as fh:
                data = tomllib.load(fh)
        except Exception:
            continue
        name = data.get("package", {}).get("name")
        if name:
            names.add(name)
    return names


def validate(path: pathlib.Path, zugot_pkgs: set[str] | None) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    try:
        with path.open("rb") as fh:
            data = tomllib.load(fh)
    except tomllib.TOMLDecodeError as exc:
        return [f"TOML parse error: {exc}"], []

    for section in REQUIRED_SECTIONS:
        if section not in data:
            errors.append(f"missing [{section}] section")

    pkg = data.get("package", {})
    for field in REQUIRED_PACKAGE_FIELDS:
        if field not in pkg:
            errors.append(f"[package].{field} missing")

    name = pkg.get("name", "")
    if name and path.stem != name:
        errors.append(f"filename '{path.stem}.toml' != [package].name '{name}'")

    parts = path.parts
    try:
        category = parts[parts.index("recipes") + 1]
    except (ValueError, IndexError):
        category = ""
    if category and category not in KNOWN_CATEGORIES:
        errors.append(f"unknown category directory '{category}'")
    groups = pkg.get("groups") or []
    if groups and category not in groups:
        warnings.append(f"category dir '{category}' not in groups {groups}")

    src = data.get("source", {})
    version = pkg.get("version", "")
    url = src.get("url", "")
    if version and url and version not in url:
        warnings.append(f"version '{version}' not found in source.url")

    if "sha256" not in src:
        errors.append("[source].sha256 missing (use empty string if unreleased)")
    elif src["sha256"] == "":
        warnings.append("[source].sha256 is empty — must be populated before merge")
    elif not re.fullmatch(r"[0-9a-fA-F]{64}", src["sha256"]):
        errors.append(f"[source].sha256 is not a 64-char hex digest")

    depends = data.get("depends", {})
    if "runtime" not in depends:
        errors.append("[depends].runtime missing")
    if "build" not in depends:
        errors.append("[depends].build missing")

    if zugot_pkgs is not None:
        all_deps = list(depends.get("runtime", [])) + list(depends.get("build", []))
        for dep in all_deps:
            if dep not in zugot_pkgs and dep != name:
                warnings.append(f"dep '{dep}' not provided by zugot")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", help="recipe .toml files (default: all)")
    parser.add_argument("--zugot", type=pathlib.Path, help="path to zugot checkout for dep checks")
    args = parser.parse_args()

    repo_root = pathlib.Path(__file__).resolve().parent.parent
    if args.paths:
        files = [pathlib.Path(p).resolve() for p in args.paths]
    else:
        files = sorted((repo_root / "recipes").rglob("*.toml"))

    zugot_pkgs: set[str] | None = None
    if args.zugot:
        zugot_pkgs = collect_zugot_packages(args.zugot.resolve())
        print(f"[info] loaded {len(zugot_pkgs)} package names from {args.zugot}")

    total_errors = 0
    total_warnings = 0
    for f in files:
        errors, warnings = validate(f, zugot_pkgs)
        rel = f.relative_to(repo_root) if repo_root in f.parents else f
        for w in warnings:
            print(f"warning: {rel}: {w}")
        for e in errors:
            print(f"error:   {rel}: {e}")
        total_errors += len(errors)
        total_warnings += len(warnings)

    print(f"\n{len(files)} recipes checked — {total_errors} error(s), {total_warnings} warning(s)")
    return 1 if total_errors else 0


if __name__ == "__main__":
    sys.exit(main())
