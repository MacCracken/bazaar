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

- **Recipe version sweep — 58 GitHub-hosted recipes bumped to their latest upstream release** (`[package].version` + the tag embedded in `[source].url`), resolved via `git ls-remote --tags` with a downgrade guard. Notables: `ollama` 0.6.2→0.24.0, `syncthing` 1.29.6→2.1.0, `fzf` 0.61.1→0.73.1, `hyprland` 0.48.1→0.55.2. `sha256` left empty by design (drafting-grace, [audit F7](docs/audit/2026-04-16.md)); major-version jumps (e.g. syncthing 1→2) may need build-recipe follow-up. **Deferred** (need per-source handling, untouched): 23 non-GitHub recipes; 5 non-semver GitHub tag schemes (`llama-cpp`, `jq`, `audacity`, `xarchiver`, `stable-diffusion-cpp`); 2 where the recipe is already ahead of the latest plain-semver tag (`piper-tts` calver, `swaylock-effects`). `slurp` and `system-config-printer` were already current.

### Fixed

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
