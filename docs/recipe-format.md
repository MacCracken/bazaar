# Recipe Format

Bazaar recipes are `.cyml` files — TOML syntax with a Cyrius-friendly extension (see [ADR-001](adr/001-cyml-over-toml.md)). This document describes the full schema.

## Minimal example

```toml
[package]
name        = "neovim"
version     = "0.11.1"
description = "Neovim — hyperextensible Vim-based text editor"
license     = "Apache-2.0"
groups      = ["editors"]

[source]
url    = "https://github.com/neovim/neovim/archive/refs/tags/v0.11.1.tar.gz"
sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

[depends]
runtime = ["glibc", "luajit", "libuv", "msgpack-c", "tree-sitter"]
build   = ["cmake", "make", "gcc", "gettext"]

[build]
configure = "cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr"
make      = "cmake --build build -j$(nproc)"
check     = ""
install   = "DESTDIR=$PKG cmake --install build"
```

## Fields

### `[package]` — metadata (required)

| field | required | notes |
|---|---|---|
| `name` | yes | Installed package name. Must equal filename stem *unless* `pkgbase` is set. |
| `version` | yes | Upstream version. Must appear in `[source].url` (warning if not). |
| `description` | yes | One-line human description. |
| `license` | yes | SPDX identifier (`MIT`, `Apache-2.0`, `GPL-3.0-only`, etc.). |
| `groups` | yes | Array of tags. First group typically matches the category directory. |
| `pkgbase` | no | Filename stem alias. Set for parallel versions or filesystem-unsafe names. See [ADR-003](adr/003-pkgbase-for-filename-divergence.md). |

### `[source]` — where to fetch (required)

| field | required | notes |
|---|---|---|
| `url` | yes | HTTPS URL to a versioned source tarball. |
| `sha256` | yes | 64-char hex digest of the tarball. Empty is allowed during drafting but blocks merge. |

### `[depends]` — dependency graph (required)

| field | required | notes |
|---|---|---|
| `runtime` | yes | Packages that must be installed for the binary to run. |
| `build` | yes | Additional packages needed only to compile. Sandbox has no network, so anything the build invokes must be here. |

Dep names must resolve against `zugot ∪ bazaar` — the validator enforces this at CI time. Use zugot's canonical names:
- No `-dev` suffix — runtime package ships headers.
- `lib` prefix follows upstream naming, no filesystem-unsafe characters (`curl` but `libuv`, `x264` but `libvpx`, `libsigcpp` *not* `libsigc++`).
- For Python bindings: `pycups`, `pycurl` (short form in zugot 1.0.0+).

If a dep doesn't resolve, the validator errors with `dep 'X' not provided by zugot or bazaar`. Either add `X` to bazaar in a separate recipe, or file the request against zugot.

### `[build]` — how to compile + install (required)

All values are shell snippets executed in the source tree, in order. `$PKG` is the install prefix (use `DESTDIR=$PKG` or equivalent).

| field | required | purpose |
|---|---|---|
| `configure` | at least one of | Pre-build configuration. Empty string if none. |
| `make` | these three | The actual compile step. |
| `install` | must be set | Copy artifacts under `$PKG`. |
| `check` | optional | Test suite. Runs after `make` if non-empty. |

Multi-line scripts use TOML triple-quoted strings:

```toml
install = """
mkdir -p $PKG/usr/bin
cp build/mytool $PKG/usr/bin/
"""
```

### `pkgbase` example — parallel Python slots

```toml
# File: recipes/tools/cpython-3.14.cyml

[package]
name    = "python3.14"
pkgbase = "cpython-3.14"
version = "3.14.0"
...
```

See [ADR-003](adr/003-pkgbase-for-filename-divergence.md) for when this field applies.

## Validation

The validator (`scripts/validate_recipes.cyr`) checks:

- [x] TOML/CYML parses
- [x] Required keys present: `name`, `version`, `description`, `license`, `groups`, `url`, `sha256`, `runtime`, `make`, `install`
- [x] Filename stem matches `name` (or `pkgbase` if set)
- [x] `name` and `pkgbase` are ASCII-only (homoglyph defense — [audit F3](audit/2026-04-16.md))
- [x] `[source].url` uses `https://` (no HTTP, FTP, file://, git+ssh:// — [audit F4](audit/2026-04-16.md))
- [x] `sha256` is 64-char hex (warns if empty, errors on invalid format)
- [x] Every `[depends]` entry resolves against `zugot ∪ bazaar` — see [ADR-006](adr/006-zugot-as-cyrius-dep.md)
- [x] Version string appears in source URL (warning)
- [x] Version has no shell metacharacters (warning — [audit F5](audit/2026-04-16.md))

It does **not** currently check:

- [ ] Section membership (e.g. `sha256` could be at top-level and still pass) — limitation of the stdlib TOML parser, see [ADR-002](adr/002-cyrius-native-validator.md)
- [ ] License is a real SPDX identifier
- [ ] URL is reachable
- [ ] Typosquat detection against existing package names — reviewer responsibility, [audit F6](audit/2026-04-16.md)

See [`validator.md`](validator.md) for how to run and extend it.

## Future schema additions

Being considered:

- `[security]` block (hardening flags) — would align bazaar with zugot's schema
- `[source].patches` — local patch application before build
- `[source].git` / `[source].commit` — build from a git revision (currently only tarballs)

None of these are currently enforced. Recipes can include them speculatively but the validator will ignore them.
