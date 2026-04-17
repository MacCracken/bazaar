# ADR-003: `pkgbase` Field for Filename / Package Name Divergence

**Status**: Accepted
**Date**: 2026-04-16
**Context**: The validator enforces `filename_basename == [package].name` to catch typo-class bugs (we found `python3 → python`, `libcurl → curl`, and others this way). But some legitimate packages can't follow the rule:

1. **Parallel versions**: zugot ships `python3.12`, `python3.13`, and `python3.14` side-by-side. Each lives in its own recipe (`cpython-3.12.cyml` etc.) so filesystems can coexist, but the installed package name is the version slot.
2. **Filesystem-unsafe characters**: `libsigc++` has a `+` which is awkward in paths and URLs. Zugot stores it as `libsigcpp.cyml`.
3. **Scope qualifiers**: `kernel.cyml` installs as `kernel-edge` to disambiguate from the default kernel.

## Decision

Add an optional `[package].pkgbase` field. When set, the filename stem must equal `pkgbase`; `name` can diverge freely. When absent, filename stem must equal `name` (unchanged default).

```toml
[package]
name    = "python3.14"
pkgbase = "cpython-3.14"    # filename must be cpython-3.14.cyml
```

## Rationale

- **Arch Linux precedent**: `pkgbase` is the PKGBUILD field for exactly this case (one source tree producing multiple installed packages). Familiar to packaging contributors.
- **Opt-in**: the 99% case stays strict. Typos still get caught.
- **Single field**: no need for a separate "filename" or "slot" concept; `pkgbase` is expressive enough for all three motivating cases.
- **Error messages clarify the rule**: validator says `"filename stem 'X' != pkgbase 'Y'"` when the field is present, so contributors who set it wrong know what to fix.

## Consequences

- Recipes that ship parallel versions can now land in bazaar without working around the validator.
- The validator cannot help contributors realize they *should* use `pkgbase` — it just accepts it if present. Reviewer still has to catch "actually this recipe should use pkgbase" cases.
- If a recipe sets `pkgbase` unnecessarily (for a simple package that doesn't need it), nothing breaks, but it's dead metadata. Worth flagging in review.

## Test Coverage

- `tests/fixtures/pkgbase_ok/` — `cpython-3.14.cyml` with `name = "python3.14"`, `pkgbase = "cpython-3.14"` → passes
- `tests/fixtures/pkgbase_mismatch/` — `pkgbase` set but doesn't match filename stem → errors

## References

- Arch Linux [`pkgbase`](https://wiki.archlinux.org/title/PKGBUILD#pkgbase) documentation
- Zugot's 10 filename/name-diverging recipes (parallel pythons, postgresql17, libsigc++, kernel-edge, etc.)
