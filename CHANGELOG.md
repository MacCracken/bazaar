# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.0.1] - 2026-04-28

Lockstep release with zugot 1.0.1 — `[deps.zugot].tag` bumped accordingly. `dist/zugot.cyr` is byte-identical between zugot 1.0.0 and 1.0.1, so `cyrius.lock` is unchanged from 1.0.0.

### Changed

- **Cyrius toolchain bumped to 5.7.30** in `cyrius.cyml` (was 5.2.0). Validator builds and validates the full 90-recipe corpus with 0 errors; all 13 fixture tests pass; bench within 2× baseline.
- **`[deps.zugot].tag` bumped to 1.0.1** to track zugot's latest release (lockstep guard in `release.yml` enforces this on tag push).
- **`cyrius.cyml` modernized**: `package.version` now pulled from `VERSION` via `${file:VERSION}` (matches nous/daimon), so the manifest and `VERSION` file can never drift. Added `repository` field.
- **CI install path is now a versioned tarball** (`cyrius-<v>-x86_64-linux.tar.gz`) instead of `curl … install.sh | sh` — closes [audit/2026-04-16.md](docs/audit/2026-04-16.md) F9 surface. Toolchain version is read from `cyrius.cyml` so the manifest is the single source of truth.
- **`validate-recipes.yml`** picks up daimon-style ergonomics: `concurrency:` group, graceful `cyrius deps --verify` (only when `cyrius.lock` is present), `${CYRIUS_VERSION:-…}` env override, parallel docs-check job (CHANGELOG / required files / version-in-CHANGELOG enforcement), `cyrius lint` + `cyrius vet` stages.
- **`release.yml`** ships `cyrius.lock` as a release artifact for build-reproducibility, and extracts release notes from `CHANGELOG.md` instead of GitHub's auto-generated PR list.
- **Validator line-length lint** cleared by shortening one warning string. CI lint step is now fail-on-warn (was advisory).

### Added

- **`CHANGELOG.md`** (this file). Required by the docs job in `validate-recipes.yml`; release notes are extracted from the `## [X.Y.Z]` section matching the tag.
- **`LICENSE`** — pointer file for `GPL-3.0-only`. Was missing despite `cyrius.cyml` declaring the license; the new docs check surfaced it.

### Documentation

- `docs/validator.md`: corrected the `args_init` stack-dangle note. The bug is **still present in 5.7.30** stdlib `lib/args.cyr` (function-local `var buf[4096]` whose address is stored in the `_args_base` global) — the validator's inline replacement reader stays load-bearing until cyrius fixes it upstream.
- `docs/adr/002-cyrius-native-validator.md` and `docs/audit/2026-04-16.md` aligned to the 5.7.30 toolchain.

## [1.0.0] - 2026-04-16

First tagged release. Bazaar = community recipe overlay for AGNOS, sitting on top of zugot (the official recipe set). 90 recipes across 8 categories.

### Added

- **Cyrius-native validator** ([ADR-002](docs/adr/002-cyrius-native-validator.md)). `scripts/validate_recipes.cyr` walks `recipes/` and checks each `.cyml` against the recipe schema. Replaces the original Python prototype — ~12× faster, zero runtime deps.
- **Zugot cross-check** ([ADR-006](docs/adr/006-zugot-as-cyrius-dep.md)). Validator imports zugot's generated `dist/zugot.cyr` via a `[deps.zugot]` block in `cyrius.cyml` and rejects any bazaar recipe whose deps don't resolve against zugot ∪ bazaar. Caught the `libsigc++ → libsigcpp` rename mechanically.
- **`pkgbase` field** ([ADR-003](docs/adr/003-pkgbase-for-filename-divergence.md)) — lets a recipe's filename stem differ from `[package].name` for parallel-version cases (e.g., `cpython-3.14.cyml` declaring `name = "python3"`).
- **13 fixture tests + a benchmark harness with regression check** (`benches/run.sh --check` fails CI if median > 2× the historical baseline).
- **Three-way version lockstep** between git tag, `VERSION` file, and `[deps.zugot].tag` enforced by `release.yml`.

### Security ([audit/2026-04-16.md](docs/audit/2026-04-16.md))

Six findings addressed in this release; five tracked or accepted. Full audit doc covers the threat model and the rationale for each.

- **F1** — All third-party GitHub Actions SHA-pinned (`actions/checkout`, `softprops/action-gh-release`) against tag-retargeting attacks. Same mitigation class as CVE-2025-30066 (`tj-actions/changed-files`).
- **F2** — Workflows declare `permissions: contents: read`; release job opts up to `write` only where required.
- **F3** — Validator rejects non-ASCII bytes in `[package].name` and `pkgbase` (homoglyph defense — Cyrillic `е` vs Latin `e`, etc.).
- **F4** — Validator errors on any `[source].url` not using `https://`.
- **F5** — Validator warns on shell metacharacters or leading `-` in `[package].version`.
- **F8** — `${{ github.base_ref }}` passed through `env:` in the GPG-check step instead of being interpolated into the shell string.
