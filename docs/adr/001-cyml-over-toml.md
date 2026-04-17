# ADR-001: Use `.cyml` Extension for Recipes

**Status**: Accepted
**Date**: 2026-04-16
**Context**: Initial bazaar recipes used `.toml` extension. Sibling recipe repo [zugot](https://github.com/MacCracken/zugot) uses `.cyml` (Cyrius Markup Language — TOML syntax, different extension).

## Decision

Rename all bazaar recipes from `*.toml` to `*.cyml`. Syntax remains TOML-compatible.

## Rationale

- **Consistency with zugot**: bazaar recipes resolve dependencies against zugot's package set. Same extension signals same schema family.
- **Signals parseability by Cyrius tooling**: `#ref "file.cyml"` is a standard Cyrius preprocessor directive; `.toml` would require a separate code path.
- **Room to diverge**: if the schema ever needs Cyrius-specific extensions (triple-quoted multiline strings, include directives), the `.cyml` extension accommodates them without forcing all-TOML-or-nothing.

## Consequences

- All existing tooling that reads recipes had to update its file glob (`**/*.toml` → `**/*.cyml`).
- Files remain parseable by any stock TOML parser today — the migration was purely a rename.
- Contributors coming from Arch/Alpine/Debian backgrounds who instinctively write `.toml` need to be told.

## References

- [cyrius-guide.md § Ref Directive](https://github.com/MacCracken/cyrius/blob/main/docs/cyrius-guide.md) — `#ref "config.cyml"`
- [zugot recipe format](https://github.com/MacCracken/zugot/blob/main/README.md)
