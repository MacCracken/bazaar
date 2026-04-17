#!/usr/bin/env bash
# tests/run.sh — validator test suite
#
# Builds the validator if needed, then runs it against each fixture in
# tests/fixtures/ and asserts the exit code and the number of error/warning
# lines match what the fixture is supposed to demonstrate.
#
# Usage: tests/run.sh
# Exit:  0 if all fixtures pass, 1 otherwise.

set -u
cd "$(dirname "$0")/.."

VALIDATOR=build/bazaar-validate
if [ ! -x "$VALIDATOR" ] || [ "$VALIDATOR" -ot scripts/validate_recipes.cyr ]; then
    mkdir -p build
    cyrius build scripts/validate_recipes.cyr "$VALIDATOR" >/dev/null 2>&1
fi

# fixture            expected_exit  expected_errors  expected_warnings
CASES=(
    "ok                  0  0  0"
    "missing_name        1  1  0"
    "wrong_filename      1  1  0"
    "bad_sha_len         1  1  0"
    "non_hex_sha         1  1  0"
    "missing_source_key  1  2  0"
    "empty               1  1  0"
)

pass=0
fail=0
for row in "${CASES[@]}"; do
    read -r name exp_exit exp_err exp_warn <<<"$row"
    out=$("$VALIDATOR" "tests/fixtures/$name/recipes" 2>&1)
    got_exit=$?
    # Parse the summary line: "N recipes checked — E error(s), W warning(s)"
    summary=$(printf '%s\n' "$out" | grep -E 'recipes checked' || true)
    got_err=$(printf '%s\n' "$summary" | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' || echo 0)
    got_warn=$(printf '%s\n' "$summary" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' || echo 0)

    if [ "$got_exit" = "$exp_exit" ] && [ "$got_err" = "$exp_err" ] && [ "$got_warn" = "$exp_warn" ]; then
        printf 'PASS  %-22s exit=%s errors=%s warnings=%s\n' "$name" "$got_exit" "$got_err" "$got_warn"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-22s expected exit=%s err=%s warn=%s, got exit=%s err=%s warn=%s\n' \
            "$name" "$exp_exit" "$exp_err" "$exp_warn" "$got_exit" "$got_err" "$got_warn"
        printf '      output:\n%s\n' "$out" | sed 's/^/      /'
        fail=$((fail + 1))
    fi
done

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
