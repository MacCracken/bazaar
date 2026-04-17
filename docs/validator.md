# The Validator

`scripts/validate_recipes.cyr` is a Cyrius program that walks `recipes/` and checks each `.cyml` file against the recipe schema. It's the primary gate on every PR.

## Quick reference

```sh
# Build
cyrius build scripts/validate_recipes.cyr build/bazaar-validate

# Run on the full corpus
./build/bazaar-validate

# Run on a specific subdirectory (tests + fixtures use this)
./build/bazaar-validate recipes/editors
./build/bazaar-validate tests/fixtures/ok/recipes

# Test suite
tests/run.sh

# Benchmark with regression check
benches/run.sh --check
```

## What it checks

| Check | Severity | Notes |
|---|---|---|
| File parses as TOML/CYML | error | Empty files fail here. |
| Required keys present | error | `name`, `version`, `description`, `license`, `groups`, `url`, `sha256`, `runtime`, `make`, `install`. |
| Filename stem matches `[package].name` (or `pkgbase` if set) | error | Catches typos and copy-paste mistakes. |
| `[package].name` / `pkgbase` is ASCII-only | error | Blocks homoglyph attacks — see [`audit/2026-04-16.md`](audit/2026-04-16.md) F3. |
| `[source].url` uses `https://` scheme | error | No HTTP, FTP, file://, git+ssh:// — see audit F4. |
| `sha256` is 64-char hex | error | Must be a real digest. |
| `sha256` is empty | warning | Grace period during drafting. Reviewer requires real digest before merge. |
| Version appears in source URL | warning | Helps catch mismatched version bumps. |
| `version` has no shell metacharacters | warning | Guards against command injection if interpolated into `[build]` — see audit F5. |
| Every `[depends]` entry resolves against `zugot ∪ bazaar` | error | Cross-check runs against the hashmap populated at startup from `zugot_names()` (imported via `[deps.zugot]`) plus names collected from bazaar's own recipes. See [ADR-006](adr/006-zugot-as-cyrius-dep.md). |

Exit code: `0` clean, `1` any errors, `2` I/O or usage error.

## Architecture

One source file, two kinds of deps in `cyrius.cyml`:

```toml
[deps]
stdlib = ["string", "fmt", "alloc", "vec", "str", "io", "syscalls", "fs", "toml", "hashmap"]

[deps.zugot]
git    = "https://github.com/MacCracken/zugot.git"
tag    = "1.0.0"
modules = ["dist/zugot.cyr"]
```

`hashmap` powers O(1) dep lookups. `zugot` provides a generated `zugot_names(out)` function used to seed the universe of valid package names (see [ADR-006](adr/006-zugot-as-cyrius-dep.md)).

The program flow:

1. `alloc_init()` + custom cmdline reader (stdlib `args_init` has a stack-dangle bug in 5.1.10, fixed locally)
2. Build the package-name universe: seed from `zugot_names()`, then first-pass scan over `recipes/` collecting every bazaar `[package].name`
3. `find_files(root, "cyml")` — walks the tree via `getdents64`
4. Second pass: for each file, `toml_parse_file()` → check required keys → filename match → sha256 format → https URL → shell-metachar version → cross-check every `[depends]` entry against the universe
5. Print summary, exit with error count

### A limitation: flat-pair mode

Cyrius stdlib `lib/toml.cyr` doesn't parse `[section]` headers (only `[[array-of-tables]]`). It flattens all key/value pairs into one unnamed section. The validator works around this by treating the recipe as a flat key/value map. Consequences:

- ✅ Can verify required keys exist anywhere in the file
- ❌ Can't enforce that `sha256` is inside `[source]` specifically

When nous' fuller `cyml_parse` lands in stdlib, the validator should switch to it (see [ADR-002](adr/002-cyrius-native-validator.md)).

## Extending the validator

Additional checks go in `validate_file()`. Pattern:

```cyr
var my_field = toml_get(pairs, "my_field");
if (my_field > 0 && is_bad(my_field) == 1) {
    report_error(path, "my_field is malformed");
}
```

Helpers already defined:

- `report_error(path, msg_cstr)` — prints `<path>: error: <msg>` and bumps `g_errors`
- `report_warn(path, msg_cstr)` — same for warnings
- `require_key(pairs, key_cstr, path)` — emits an error if the key is missing

Then add a fixture under `tests/fixtures/` that triggers the new check, and a row in `tests/run.sh`:

```sh
run_case  my_new_check  1  1  0    # exit=1, 1 error, 0 warnings
```

Rebuild and run `tests/run.sh` to confirm.

## Performance

Validator is ~3.5ms median on 90 recipes on commodity Linux — ~12× faster than the Python prototype it replaced. (The original pre-cross-check validator was ~2.3ms; adding the zugot cross-check with a 592-name universe added ~1.2ms.) The bottleneck is filesystem (`getdents64` + `openat` + `read` per recipe). See `benches/bench-history.csv` for the tracked history.

`benches/run.sh --check` fails CI if the median exceeds 2× the best historical median. That's the regression gate.

## CI integration

Configured in `.github/workflows/validate-recipes.yml`:

1. Install Cyrius toolchain (`curl https://…/install.sh | sh`)
2. `cyrius deps` — resolve stdlib + `[deps.zugot]` into `lib/` (pins to zugot tag from `cyrius.cyml`)
3. `cyrius build scripts/validate_recipes.cyr build/bazaar-validate`
4. `./build/bazaar-validate` — validate live recipes including the zugot ∪ bazaar cross-check
5. `sh tests/run.sh` — 13 fixture tests
6. `sh benches/run.sh --check` — regression check
7. Advisory GPG signature check on PR commits

The workflow exposes a `workflow_call:` trigger so `release.yml` can gate tagged releases on it. Scripts are POSIX `sh`, not bash — see [ADR-004](adr/004-posix-sh-for-ci-scripts.md). Third-party actions are SHA-pinned — see [audit/2026-04-16.md](audit/2026-04-16.md) F1.

## Known rough edges

- **Cyrius 5.1.10 `lib/args.cyr` stack-dangle** — validator includes an inline replacement reader. Remove when stdlib is fixed upstream.
- **Cyrius stdlib `toml` parser flattens sections** — the validator can check required keys exist but not enforce section membership. Switch to nous' `cyml_parse` when it lands in stdlib.
- **Filename/name mismatch error doesn't suggest `pkgbase`** — just says the stems don't match. If a contributor hits this legitimately (parallel version), they have to find [ADR-003](adr/003-pkgbase-for-filename-divergence.md) themselves.
- **Empty `sha256` is a warning, not an error** — intentional drafting grace period. A `--strict` mode that errors on this, toggled on for merge-targeting PRs, is tracked in [audit F7](audit/2026-04-16.md).
- **Typosquat detection is manual** — Levenshtein-1 checks live with reviewers for now. Tracked in [audit F6](audit/2026-04-16.md).
