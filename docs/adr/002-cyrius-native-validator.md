# ADR-002: Cyrius-Native Recipe Validator

**Status**: Accepted
**Date**: 2026-04-16
**Context**: Recipe validation needs to run on every PR. The initial prototype was a Python script using `tomllib`. Cyrius is the AGNOS ecosystem's sovereign language — every other official tool (`ark`, `nous`, `takumi`) is already written in it.

## Decision

Rewrite the validator in Cyrius as `scripts/validate_recipes.cyr`. Drop the Python implementation.

## Rationale

- **Ecosystem alignment**: bazaar tooling should match the rest of AGNOS. A Python dep in a sovereign stack is a supply-chain hole.
- **Speed**: Cyrius validator runs ~18× faster than Python on the 90-recipe corpus (median 2.3ms vs 43ms). Most of Python's overhead is interpreter startup + `tomllib` init — costs paid on every PR.
- **Zero runtime deps**: static 312KB ELF, no libc, no external libraries. Works on minimal CI images.
- **Proof point**: exercising Cyrius on a real, boring task surfaces real gaps (we found a stack-dangle bug in `lib/args.cyr` and an incomplete `lib/toml.cyr` section parser while writing this).

## Consequences

- CI installs Cyrius 5.7.30 on every run from the published release tarball, pinned by `cyrius = "..."` in `cyrius.cyml`. Single network dependency.
- Recipe parsing is limited to what stdlib `lib/toml.cyr` handles — currently only flat-pair mode, not section-aware. Validator checks required keys but can't enforce section membership (e.g. "sha256 must be in `[source]`"). Sufficient for the schema as-is.
- CYML-authoring errors surface to contributors in Cyrius error messages rather than Python stack traces, which is fine but unfamiliar.
- Writing the first Cyrius-native tool for this repo creates a template for future tooling (dep cross-check, recipe generator, etc.).

## Alternatives Considered

- **Python**: fast to write, but breaks sovereignty + costs a dep.
- **Rust**: idiomatic for AGNOS-adjacent tools (`vidya` is Rust), but even larger dep footprint than Python for a one-shot CLI.
- **Shell + jq**: jq doesn't speak TOML natively; would need a preprocessor.

## References

- `scripts/validate_recipes.cyr` — the validator
- `bench-history.csv` — recorded timings
- Cyrius 5.7.30 `lib/toml.cyr`, `lib/fs.cyr`, `lib/args.cyr`
