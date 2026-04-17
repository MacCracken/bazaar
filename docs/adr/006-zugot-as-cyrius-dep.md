# ADR-006: Zugot as a Cyrius `[deps]` Dependency

**Status**: Accepted
**Date**: 2026-04-16
**Context**: Bazaar recipes declare runtime/build dependencies that must resolve against zugot's canonical package set plus bazaar's own recipes. Previously this resolution was verified manually by Python scripts running against a local zugot checkout. That's fragile (no version pin, drifts silently) and duplicates the Cyrius dep-resolution machinery we already use for language modules.

## Decision

Zugot publishes `dist/zugot.cyr` — an auto-generated Cyrius module exposing `zugot_names(out)`, which populates a vec with every package name currently in zugot. Bazaar declares zugot as a standard `[deps.zugot]` entry in `cyrius.cyml` (same mechanism sigil uses to depend on agnosys). The validator imports the module, populates a hashmap at startup, and rejects any bazaar recipe whose dependencies don't resolve against the union of zugot + bazaar names.

```toml
# bazaar/cyrius.cyml
[deps.zugot]
git    = "https://github.com/MacCracken/zugot.git"
path   = "../zugot"
branch = "main"
modules = ["dist/zugot.cyr"]
```

## Rationale

- **First-class, version-pinnable**: zugot's dep resolution now goes through `cyrius deps` like any other module. Pin a tag/SHA once zugot publishes them; `path = "../zugot"` lets contributors test against a local checkout.
- **No runtime clone**: the names are baked into the validator binary at build time. CI doesn't need a second `git clone`.
- **Matches the ecosystem pattern**: sigil→agnosys (kernel interfaces), ark→nous (resolver). Zugot is now the same kind of upstream for bazaar.
- **Declarative coupling**: the audit trail ("which zugot was bazaar validated against?") is the zugot git SHA at the time the dist module was regenerated. Contributors can inspect `lib/zugot.cyr` directly.

## Consequences

- **Zugot must regenerate `dist/zugot.cyr` on every release** via `scripts/gen-dist.sh`. This is a cheap scan (~500ms) and can run in zugot's CI.
- **Bazaar's validator requires the `hashmap` stdlib module** — added to `cyrius.cyml [deps].stdlib` to support O(1) membership checks across ~600 names. Without it, the cross-check was ~2× the runtime of the rest of validation combined.
- **Rename drift is caught mechanically**: during this session we discovered zugot had renamed `libsigc++` → `libsigcpp` only after bazaar's `cyrius build` failed the cross-check. Previous-manual process would have missed this.
- **Name collisions are silently deduplicated**: if both zugot and bazaar define a package with the same name, the map holds it once. This is acceptable (same name means same package semantically) but worth a future warning.
- **CI must run `cyrius deps` before build**: the workflow already does (step 3). Not a change.

## What doesn't live in `[deps.zugot]`

- **Runtime install-time resolution** — that's `ark`'s job, reading both repos' recipes directly.
- **Schema conventions** (no `-dev` split, `lib` prefix rules) — still ADR-005, still informal.

## Alternatives considered

- **Git submodule** — embeds a full zugot checkout. Too heavy (bazaar clones grow to >10 MB for data we only need the names of), and nothing to version-pin except the submodule ref.
- **CI-side env var `ZUGOT_REF=main`** — sketched in the previous conversation. Works, but needs a bespoke clone step and the "what zugot did we validate against" info lives only in CI logs.
- **Cross-check in Python** — the original `tools/check-against-zugot.py`. Works but reintroduces a Python dep, contradicting [ADR-002](002-cyrius-native-validator.md).

## References

- Sigil's [`cyrius.cyml`](https://github.com/MacCracken/sigil/blob/main/cyrius.cyml) — the `[deps.agnosys]` pattern we mirror
- [Cyrius guide — Build Tool & Dependencies](https://github.com/MacCracken/cyrius/blob/main/docs/cyrius-guide.md)
- Zugot `scripts/gen-dist.sh` — generator that produces `dist/zugot.cyr`
