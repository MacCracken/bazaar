# ADR-004: POSIX `sh` for CI Scripts

**Status**: Accepted
**Date**: 2026-04-16
**Context**: `tests/run.sh` and `benches/run.sh` were originally written in bash (arrays, `<<<` herestrings, `< <(...)` process substitution, `set -o pipefail`). CI on GitHub Actions invokes them via `sh tests/run.sh` — on Ubuntu, that's `dash`, which rejects all of the above.

## Decision

Both scripts use `#!/bin/sh` and stay within POSIX. No bash features.

## Rationale

- **Works under any invocation**: `./tests/run.sh`, `sh tests/run.sh`, and `bash tests/run.sh` all behave the same.
- **One less thing to get wrong in CI**: the workflow file can call scripts however it wants without needing `bash` explicitly.
- **No real cost**: bazaar's scripts are simple — a fixtures-driven test loop and a timing loop. The bash features we lost (arrays, herestrings) replace cleanly with POSIX equivalents (function calls with positional args, tempfiles).

## What Changed

### `tests/run.sh`

| bashism | replacement |
|---|---|
| `CASES=( "row1" "row2" ... )` array | `run_case()` function + explicit positional calls |
| `read -r a b c <<<"$row"` | function parameters `$1 $2 $3` |

### `benches/run.sh`

| bashism | replacement |
|---|---|
| `set -o pipefail` | dropped (only meaningful inside pipelines; we can check exit codes explicitly if needed) |
| `read ... < <(python3 -c ...)` | python writes to `/tmp/bazaar-bench.txt`, shell `read < file` |

## Consequences

- Any future script added under `tests/` or `benches/` should also be `#!/bin/sh` and POSIX-only.
- If a script genuinely needs bash (arrays with dynamic indexing, associative arrays, etc.), it should be `.bash` with `#!/usr/bin/env bash` and the CI step must invoke it with `bash`, not `sh`.
- Reviewers should `shellcheck -s sh` any POSIX script to catch drift.

## Non-Goals

- We don't port the Cyrius validator to sh. It stays `.cyr`.
- We don't refuse to use Python in scripts — `benches/run.sh` calls Python for timing math; that's fine, Python is standard and POSIX-neutral.
