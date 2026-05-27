# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.0.2] - 2026-05-27

Lockstep release with zugot 1.0.2 — `[deps.zugot].tag` bumped accordingly. `dist/zugot.cyr` is byte-identical between zugot 1.0.1 and 1.0.2 (hash `61205111…` unchanged), so the zugot module entry in `cyrius.lock` is unchanged.

### Changed

- **Cyrius toolchain bumped to 6.0.3** in `cyrius.cyml` (was 5.7.30) — a major-version upgrade. Validator builds and validates the full recipe corpus with 0 errors; all 13 fixture tests pass; bench median 2.879ms, within 2× baseline.
- **`[deps.zugot].tag` bumped to 1.0.2** to track zugot's latest release (lockstep guard in `release.yml` enforces this on tag push).
- **`cyrius.lock` now records the full transitive dependency set** (21 modules — stdlib + zugot) rather than only the zugot dist module. This reflects the 6.0.x lock format; regenerated via `cyrius deps` and verified with `cyrius deps --verify`. The zugot dist-module hash is unchanged.
- **Validator argv handling switched to stdlib `args` (`args_init`/`argc`/`argv`).** The 6.0.3 stdlib fixes the `args_init` stack-dangle bug (function-local `var buf` whose address was stored in the `_args_base` global — now heap-allocated via `alloc`), so the validator's hand-rolled `/proc/self/cmdline` reader (`read_cmdline()`/`arg_at()`) and its 4 KB global buffer were removed. `"args"` added to `[deps].stdlib`. The optional recipe-root arg is now guarded on `argc()` because stdlib `argv(n)` returns a pointer past the last arg (not `0`) when `n == argc()`.

- **Recipe version sweep — 83 of 90 recipes updated to their latest upstream release** (`[package].version` + the version embedded in `[source].url`). `sha256` left empty by design (drafting-grace, [audit F7](docs/audit/2026-04-16.md)); major-version jumps (e.g. `syncthing` 1→2, `libreoffice` 25.2→26.2, `gimp` 3.0→3.2, `ffmpeg` 7→8) may need build-recipe follow-up. Resolution was per-source:
  - **67 GitHub** — `git ls-remote --tags` with a downgrade guard; scheme-aware for non-semver tags (`llama-cpp` b5170→b9370, `jq` jq-1.7.1→1.8.1, `audacity` Audacity-3.7.3→3.7.7, `xarchiver` 0.5.4.23→0.5.4.26).
  - **6 GNOME** — `cache.json` per module, filtered to latest stable; URLs reconstructed since the branch directory tracks the version. `gtkmm3` correctly held to the GTK3 series (3.24.9→3.24.10, *not* the gtkmm4 4.x the same module also publishes).
  - **17 other sources** — git (`wireguard-tools`, `wlroots`, `pass`, `grim`), GNU ftp (`parted`), XFCE/Qt/LibreOffice/GIMP/feh directory listings, SourceForge (`imlib2` 1.12.5→1.12.6, `gparted` 1.7.0→1.8.1). Every rebuilt non-GitHub URL was HEAD-verified to return 200.
  - **`inkscape`** bumped 1.4.2→1.4.4 **and** its dead `inkscape.org/gallery` URL (already 404) replaced with the derivable `media.inkscape.org` path.
  - **Two recipes had fictional tags pointing at 404s, now repaired:** `stable-diffusion-cpp` (the repo publishes no semver tags — pinned to the latest release `master-655-29ab511`, matching the project's own `master-<count>-<hash>` scheme) and `piper-tts` (the `2024.11.14` tag never existed — pinned to the real latest `2023.11.14-2`; note upstream is now superseded by the Python `OHF-Voice/piper1-gpl`, a future migration that would need a build rewrite).
  - Already current (no change): `slurp`, `system-config-printer`, `swaylock-effects`, `pass`, `grim`, `gnome-disk-utility`, `network-manager-applet`.
  - **`lmstudio`** (proprietary AppImage) bumped 0.3.16→**0.4.1** with a fully rebuilt URL: the latest version came from the [API changelog](https://lmstudio.ai/docs/developer/api-changelog), and the download host/scheme had changed (`releases.lmstudio.ai/linux/x86_64/<v>/…` → `installers.lmstudio.ai/linux/x64/<v>-<build>/…`); the rebuilt URL (build `-1`) was HEAD-verified 200. The `LM-Studio-*.AppImage` install glob is unaffected. (Still a closed-source binary repackage — worth a separate look against the source-build/sandbox trust model.)

### Fixed

- **CI Cyrius install switched to the version-managed layout** (`validate-recipes.yml`). cyrius 6.0.x's `cyrius` launcher reads the `cyrius =` pin from `cyrius.cyml` and dispatches to `~/.cyrius/versions/<pin>/bin/cyrius`; the previous flat install (copying straight into `~/.cyrius/bin`) never created `versions/<pin>/`, so `cyrius --version` failed with "manifest pins 6.0.3 but binary not installed at versions/6.0.3/bin/cyrius" — breaking CI on the 6.0.3 bump. Now installs into `~/.cyrius/versions/$CYRIUS_VERSION/` and symlinks `~/.cyrius/bin` to it (mirrors patra CI), plus a release-asset 404 pre-flight and gzip sanity check. Verified by simulating the full install + `deps`/`deps --verify`/build/validate locally.
- **Validator now walks the full recipe tree (90/90), not 64/90.** stdlib `is_dir()` uses a 32-byte `getdents64` buffer and returns "not a directory" whenever a directory's first entry (in filesystem hash order — *not* `.`/`..` first on ext4/btrfs) has a name ≥ 13 chars, so stdlib `find_files`/`dir_walk` silently skipped `recipes/ai`, `recipes/networking`, `recipes/games`, and `recipes/desktops/hyprland` — **26 recipes were never validated, locally or in CI.** Replaced the stdlib walk with a validator-local `collect_cyml()` over `getdents64` `d_type` (large-buffer `dir_ok()` fallback for `DT_UNKNOWN`). The bench rises (~2.9ms → ~3.6ms) because it now genuinely validates all 90 recipes; still within the 2× regression gate. Upstream stdlib bug reported against cyrius.

### Documentation

- `docs/validator.md`: program-flow and "known rough edges" updated for the stdlib-`args` switch, including the `argc()`-guard gotcha.
- `docs/adr/002-cyrius-native-validator.md` and `docs/audit/2026-04-16.md` aligned to the 6.0.3 toolchain.

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
