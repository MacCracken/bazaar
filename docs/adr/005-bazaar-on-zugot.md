# ADR-005: Bazaar Sits on Top of Zugot

**Status**: Accepted
**Date**: 2026-04-16
**Context**: Bazaar and zugot are both AGNOS recipe repositories, with overlapping file formats and partial overlap in intent. Without a clear trust + dependency relationship, contributors don't know where a recipe belongs, and tooling can't resolve dependencies.

## Decision

Zugot is canonical; bazaar is additive.

- **Zugot** ships the base toolchain, kernel, desktop stack, codecs, and first-party AGNOS packages. Its recipes are reviewed by the AGNOS team and define the OS itself. Recipe schema is richer (includes `[security]` hardening, `[marketplace]`, `release`, `arch`, `patches`).
- **Bazaar** is the community overlay — like AUR for Arch. Recipes may depend on anything in zugot *or* on other bazaar recipes. Schema is minimal: `[package]`, `[source]`, `[depends]`, `[build]`.
- **Resolution order**: `ark bazaar install X` looks up `X` in bazaar, then walks dependencies against the union `zugot ∪ bazaar`. If a dep isn't in either, the install fails.

## Rationale

- **Clear trust boundary**: zugot is first-party, bazaar is community. Different review standards, different sandboxing posture.
- **No dep duplication**: bazaar never redefines `glibc`, `wayland`, `python`. Zugot owns the base set.
- **Bazaar stays small**: 90 recipes today. If something becomes popular enough, it should migrate to zugot; bazaar isn't meant to grow into a full distro repo.
- **Validator contract**: bazaar's validator rejects a recipe whose deps don't resolve against `zugot ∪ bazaar`. This is the structural guarantee that keeps the trust boundary meaningful.

## Consequences

- Every bazaar PR implicitly also reviews which parts of zugot it relies on. If a new dep is needed and it's not in zugot, the PR author has two options:
  1. File an issue / recipe against zugot first.
  2. Add the dep to bazaar itself as a separate recipe (only if it's clearly community-scoped and not a foundational library).
- The cross-repo dependency check (`tools/check-against-zugot`, currently Python, eventually Cyrius) should run in bazaar CI against a pinned zugot commit.
- Schema divergence is deliberate: bazaar doesn't require `[security]` blocks since recipes run in a sandbox with no network access by default. Zugot recipes ship pre-install and need the hardening flags.

## Naming Conventions (zugot canonical)

- No `-dev` split — runtime package ships headers.
- `lib` prefix follows upstream project naming. `curl` and `luajit` have no prefix; `libsigc++` and `libuv` do.
- Parallel versions use `pkgbase` (see [ADR-003](003-pkgbase-for-filename-divergence.md)).

## References

- [`noted-issues-bazaar-finds.md`](https://github.com/MacCracken/zugot/blob/main/noted-issues-bazaar-finds.md) — cross-check report between the two repos
- Zugot's README describes its own package categories and build order
