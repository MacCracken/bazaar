#!/bin/sh
# benches/run.sh — measure validator runtime on the full recipes/ corpus
# and append a row to bench-history.csv.
#
# Usage:
#   benches/run.sh              # 20 iterations, 3 warmups, append to CSV
#   benches/run.sh --no-append  # print only, don't touch the CSV
#   benches/run.sh --check      # fail if median > 2x the baseline in the CSV
#
# CSV columns: utc_iso, git_sha, n_recipes, iterations, min_ms, median_ms, mean_ms, max_ms

set -eu
cd "$(dirname "$0")/.."

VALIDATOR=build/bazaar-validate
CSV=benches/bench-history.csv
ITERS=20
WARMUPS=3
APPEND=1
CHECK=0

for arg in "$@"; do
    case "$arg" in
        --no-append) APPEND=0 ;;
        --check)     CHECK=1; APPEND=0 ;;
        *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

if [ ! -x "$VALIDATOR" ] || [ "$VALIDATOR" -ot scripts/validate_recipes.cyr ]; then
    mkdir -p build
    cyrius build scripts/validate_recipes.cyr "$VALIDATOR" >/dev/null
fi

N_RECIPES=$(find recipes -name '*.cyml' -type f | wc -l | tr -d ' ')

# Benchmark loop. Time via Python perf_counter — portable and the interpreter
# itself is not in the hot path (we're measuring a subprocess).
python3 - "$VALIDATOR" "$ITERS" "$WARMUPS" >/tmp/bazaar-bench.txt <<'PY'
import statistics, subprocess, sys, time
validator, iters, warmups = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
for _ in range(warmups):
    subprocess.run([validator], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
samples = []
for _ in range(iters):
    t = time.perf_counter()
    subprocess.run([validator], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    samples.append((time.perf_counter() - t) * 1000.0)
# Emit space-separated stats; shell parses via read.
print(f"{min(samples):.3f} {statistics.median(samples):.3f} {statistics.mean(samples):.3f} {max(samples):.3f}")
PY

read -r MIN MEDIAN MEAN MAX < /tmp/bazaar-bench.txt
rm -f /tmp/bazaar-bench.txt

UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SHA=$(git rev-parse --short=12 HEAD 2>/dev/null || echo "unknown")

printf 'n=%s  iters=%s  min=%sms  median=%sms  mean=%sms  max=%sms\n' \
    "$N_RECIPES" "$ITERS" "$MIN" "$MEDIAN" "$MEAN" "$MAX"

if [ "$CHECK" -eq 1 ]; then
    if [ ! -s "$CSV" ]; then
        echo "no baseline in $CSV — nothing to check against" >&2
        exit 0
    fi
    BASELINE=$(awk -F, 'NR>1 {print $6}' "$CSV" | sort -n | head -1)
    LIMIT=$(python3 -c "print(${BASELINE} * 2)")
    EXCEEDED=$(python3 -c "print(1 if ${MEDIAN} > ${LIMIT} else 0)")
    if [ "$EXCEEDED" = "1" ]; then
        echo "REGRESSION: median ${MEDIAN}ms > 2x baseline ${BASELINE}ms (limit ${LIMIT}ms)" >&2
        exit 1
    fi
    echo "OK: median ${MEDIAN}ms within 2x of baseline ${BASELINE}ms"
fi

if [ "$APPEND" -eq 1 ]; then
    if [ ! -s "$CSV" ]; then
        echo "utc,sha,n_recipes,iterations,min_ms,median_ms,mean_ms,max_ms" > "$CSV"
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$UTC" "$SHA" "$N_RECIPES" "$ITERS" "$MIN" "$MEDIAN" "$MEAN" "$MAX" >> "$CSV"
    echo "appended to $CSV"
fi
