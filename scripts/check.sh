#!/bin/bash
# Correctness of forms (t) and (pt) on each dataset (not a timing): the trait-world libraries and
# PlainTables, their control without traits, must print the same summary and draw the same PNG.
# Datasets: the task's sample.csv (three Float64 columns); data/sensors.csv (a second shape: missing
# cells in four columns, a strings column); data/items.csv read with String15 among the column types
# (TraitCSV's conformance arrives in an extension). One Julia job at a time.
#
#     scripts/check.sh
set -u
cd "$(dirname "$0")/.."
ROOT=/home/hellmann/Repos/julia-trait-bound
J=${JULIA:-$ROOT/julia-1.13/julia}
LOCK=${LOCK:-/tmp/claude-1000/julia-review.lock}
OUT=${TMPDIR:-/tmp}/traitreport_check; mkdir -p "$OUT"
export JULIA_PKG_OFFLINE=true JULIA_TW_VIEWCACHE=0
run() { flock "$LOCK" nice -n 19 timeout 1800 "$J" --startup-file=no --project=$1 $2 $3 $4 $5 2>"$OUT/err" | grep -v '^T '; }
fail=0
for case in "sample $ROOT/experiments/interfaces/App/data/sample.csv" "sensors data/sensors.csv" "items data/items.csv String15"; do
    set -- $case
    name=$1 csv=$2 opt=${3:-}
    run env_t scripts/report_tables.jl "$csv" "$OUT/t_$name.png" "$opt" > "$OUT/t_$name.txt"
    run env_pt scripts/report_plaintables.jl "$csv" "$OUT/pt_$name.png" "$opt" > "$OUT/pt_$name.txt"
    if diff -q "$OUT/t_$name.txt" "$OUT/pt_$name.txt" >/dev/null && cmp -s "$OUT/t_$name.png" "$OUT/pt_$name.png" && [ -s "$OUT/t_$name.png" ]; then
        echo "CHECK $name: (t) and (pt) print the same summary and draw the same PNG ok"
    else
        echo "CHECK $name FAIL"; diff "$OUT/t_$name.txt" "$OUT/pt_$name.txt" | head; fail=1
    fi
    sed 's/^/    /' "$OUT/t_$name.txt"
done
exit $fail
