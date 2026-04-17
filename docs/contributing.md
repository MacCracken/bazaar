# Contributing to Bazaar

Bazaar is a community-overlay recipe repo for AGNOS. Recipes are reviewed for security, correctness, and coherence with the ecosystem before merge.

## What belongs here

**Yes:** open-source applications, CLI tools, editors, window managers, utilities, developer tooling that users want but that isn't foundational enough to live in [zugot](https://github.com/MacCracken/zugot).

**No:**
- Pre-compiled binaries. Recipes must build from source.
- Packages that zugot already provides. Rebuilding zugot's `glibc` in bazaar is not a thing — see [ADR-005](adr/005-bazaar-on-zugot.md).
- Anything that depends on closed-source blobs without a clear security review path.
- Forks of zugot packages. If zugot's version is outdated, open an issue there.

## Before you start

1. Check zugot for the package first: `grep -r 'name = "X"' ~/Repos/zugot --include='*.cyml'`
2. Check bazaar: `ls recipes/*/X.cyml`
3. Confirm the source is publicly downloadable over HTTPS with a stable versioned URL

## Submit a recipe

1. **Fork** the repo.
2. **Create** a recipe under the appropriate category: `recipes/{editors,tools,media,networking,security,ai,games,desktops}/mypkg.cyml`. Filename stem must match `[package].name` — see [`recipe-format.md`](recipe-format.md) for the schema.
3. **Validate locally**:
   ```sh
   cyrius deps                   # first time — pulls zugot dist module
   cyrius build scripts/validate_recipes.cyr build/bazaar-validate
   ./build/bazaar-validate       # also cross-checks your deps against zugot ∪ bazaar
   sh tests/run.sh               # optional but encouraged
   ```
4. **Sign your commit** with GPG: `git commit -S -m "add mypkg"`.
5. **Open a PR**. CI will run the validator, the test suite, the benchmark regression check, and the GPG-signature advisory.

## What reviewers look for

- All required fields present (see [`recipe-format.md`](recipe-format.md)).
- `sha256` populated with the actual digest of the source tarball, not left empty.
- Dependencies resolve against `zugot ∪ bazaar` — the validator enforces this automatically; CI fails with `dep 'X' not provided by zugot or bazaar` on an unresolved name. If a dep is missing:
  - File a request against zugot (for foundational libs), or
  - Add the dep to bazaar first in a separate PR (for community-scoped libs).
- Version in `[source].url` matches `[package].version`.
- Build instructions don't download anything beyond the declared `[source].url` (sandboxed build environment has no network).
- License field uses an SPDX identifier.
- No `git clone` or `curl` in build steps — use the declared source tarball.

## Populating `sha256`

```sh
curl -sL "https://example.org/pkg-1.2.3.tar.gz" | sha256sum
```

Or, once the rest of the recipe is ready, let `ark bazaar install --record-sha` do it for you (when that ships).

Validator warns (but doesn't error) on empty `sha256`. This is a grace period for recipes still being drafted; reviewer will require a real digest before merge.

## Reference

- [Recipe format](recipe-format.md) — complete schema
- [Validator](validator.md) — how the validator works, how to run it locally
- [ADRs](adr/) — architectural decisions and their rationale
