# Bazaar

**Persian: بازار — marketplace/gathering**

Community recipe overlay for [AGNOS](https://github.com/MacCracken/agnosticos). Like Arch's AUR, but sitting on top of [zugot](https://github.com/MacCracken/zugot) (the official AGNOS recipe set).

**Current release:** [`1.0.0`](./VERSION) — versioned [in lockstep with zugot](docs/adr/006-zugot-as-cyrius-dep.md); each bazaar tag validates against the matching zugot tag.

**Recipes:** 90 across 8 categories, all `.cyml` ([Cyrius](https://github.com/MacCracken/cyrius) markup, TOML-compatible syntax).

## How it works

1. Community members submit recipe CYMLs via pull request.
2. CI validates the recipe; maintainers review for security and correctness.
3. Users install via `ark bazaar install <package>` — builds locally in a sandbox or downloads from the build mirror.
4. Dependencies resolve against `zugot ∪ bazaar`. Bazaar recipes never redefine zugot packages.

## User commands

```sh
ark bazaar search neovim                     # find a package
ark bazaar install neovim                    # build + install
ark bazaar update                            # refresh recipe index
ark bazaar list                              # list installed
ark bazaar submit recipes/editors/neovim.cyml
```

## Recipe categories

| Directory | Contents |
|---|---|
| `recipes/editors/` | Text editors, IDEs |
| `recipes/tools/` | CLI tools, utilities |
| `recipes/media/` | Media players, editors, codecs |
| `recipes/networking/` | Network tools, VPNs, proxies |
| `recipes/security/` | Security tools, password managers |
| `recipes/ai/` | AI/ML tools, models, runtimes |
| `recipes/games/` | Games and emulators |
| `recipes/desktops/` | Wayland compositors, desktop applications |

## Trust model

- Every recipe is reviewed by a maintainer before merge.
- Community packages run in a restricted sandbox by default — no network access.
- Packages requiring network access must be explicitly approved.
- GPG signature verification on all recipe commits (advisory in CI, enforced at merge).

## Development

```sh
# Resolve deps (pulls zugot dist module via [deps.zugot])
cyrius deps

# Build the validator (requires cyrius 5.7.30+)
cyrius build scripts/validate_recipes.cyr build/bazaar-validate

# Validate all recipes (includes cross-check against zugot ∪ bazaar names)
./build/bazaar-validate

# Run the test suite (13 fixtures)
sh tests/run.sh

# Benchmark with regression check
sh benches/run.sh --check
```

CI runs all of the above on every PR via [`validate-recipes.yml`](.github/workflows/validate-recipes.yml). Tag pushes matching `[0-9]*` trigger [`release.yml`](.github/workflows/release.yml), which enforces a three-way lockstep (git tag = `VERSION` file = `[deps.zugot].tag` in `cyrius.cyml`) before cutting a GitHub release.

## Documentation

- **[Contributing](docs/contributing.md)** — how to submit a recipe, what reviewers look for
- **[Recipe format](docs/recipe-format.md)** — complete schema reference
- **[Validator](docs/validator.md)** — how the validator works, how to extend it
- **[ADRs](docs/adr/)** — architectural decisions:
  - [001 — Use `.cyml` over `.toml`](docs/adr/001-cyml-over-toml.md)
  - [002 — Cyrius-native validator](docs/adr/002-cyrius-native-validator.md)
  - [003 — `pkgbase` for filename / name divergence](docs/adr/003-pkgbase-for-filename-divergence.md)
  - [004 — POSIX `sh` for CI scripts](docs/adr/004-posix-sh-for-ci-scripts.md)
  - [005 — Bazaar sits on top of zugot](docs/adr/005-bazaar-on-zugot.md)
  - [006 — Zugot as a Cyrius `[deps]` dependency](docs/adr/006-zugot-as-cyrius-dep.md)
- **[Security audits](docs/audit/)** — periodic threat-model review:
  - [2026-04-16](docs/audit/2026-04-16.md) — external CVE/attack-class mapping, 11 findings, 6 fixed in-session

## License

Recipes are individually licensed by their authors. Repository infrastructure is GPL-3.0-only.
