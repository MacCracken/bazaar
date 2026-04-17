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
| `sha256` is 64-char hex | error | Must be a real digest. |
| `sha256` is empty | warning | Grace period during drafting. Reviewer requires real digest before merge. |
| Version appears in source URL | warning | Helps catch mismatched version bumps. |

Exit code: `0` clean, `1` any errors, `2` I/O or usage error.

## Architecture

One file, no deps beyond the Cyrius stdlib declared in `cyrius.cyml`:

```toml
[deps]
stdlib = ["string", "fmt", "alloc", "vec", "str", "io", "syscalls", "fs", "toml"]
```

The program flow:

1. `alloc_init()` + custom cmdline reader (stdlib `args_init` has a stack-dangle bug in 5.1.10, fixed locally)
2. `find_files(root, "cyml")` — walks the tree via `getdents64`
3. For each file: `toml_parse_file()` → check required keys → filename match → sha256 format
4. Print summary, exit with error count

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

Validator is ~2.3ms median on 90 recipes on commodity Linux — roughly 18× faster than the Python prototype it replaced. The bottleneck is filesystem (`getdents64` + `openat` + `read` per recipe). See `benches/bench-history.csv` for the tracked history.

`benches/run.sh --check` fails CI if the median exceeds 2× the best historical median. That's the regression gate.

## CI integration

Configured in `.github/workflows/validate-recipes.yml`:

1. Install Cyrius toolchain (`curl https://…/install.sh | sh`)
2. `cyrius deps` — resolve stdlib modules into `lib/`
3. `cyrius build scripts/validate_recipes.cyr build/bazaar-validate`
4. `./build/bazaar-validate` — validate live recipes
5. `sh tests/run.sh` — fixture tests
6. `sh benches/run.sh --check` — regression check
7. Advisory GPG signature check on PR commits

Scripts are POSIX `sh`, not bash — see [ADR-004](adr/004-posix-sh-for-ci-scripts.md).

## Known rough edges

- **Cyrius 5.1.10 `lib/args.cyr` stack-dangle** — validator includes an inline replacement reader. Remove when stdlib is fixed upstream.
- **No zugot cross-check yet** — validator only checks syntax. Dep resolution against zugot is done manually; see [`noted-issues-bazaar-finds.md`](https://github.com/MacCracken/zugot/blob/main/noted-issues-bazaar-finds.md). A `--check-against PATH` flag that reads zugot recipe names is on the roadmap.
- **Filename/name mismatch error doesn't suggest `pkgbase`** — just says the stems don't match. If a contributor hits this legitimately (parallel version), they have to find ADR-003 themselves.
