#!/bin/bash
# Fresh-process timings of TraitReport against the Python baseline.
#
#     scripts/measure.sh [runs]          # default 3 runs each
#
# Python:  pandas + matplotlib, ../experiments/interfaces/python/app.py, venv at $PYENV.
# Julia:   form (a), scripts/report_script.jl, on stock 1.13.2 and on the patched build.
# Julia is called by its binary, not through juliaup. The environment must be precompiled first
# (by each Julia: the patched build keeps its own images), in an ordinary session.
# The machine is shared: one Julia job at a time (flock), niced.
set -u
cd "$(dirname "$0")/.."
RUNS=${1:-3}
ROOT=/home/hellmann/Repos/julia-trait-bound
CSV=$ROOT/experiments/interfaces/App/data/sample.csv
PYENV=${PYENV:-/tmp/claude-1000/pyenv}
STOCK=${STOCK:-$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia}
PATCHED=${PATCHED:-$ROOT/julia-1.13/julia}
LOCK=${JULIA_LOCK:-/tmp/claude-1000/-home-hellmann-Repos-julia-trait-bound/6c8f1719-6fc1-42fb-a8dc-c45452eef443/scratchpad/julia.lock}
OUT=${TMPDIR:-/tmp}/traitreport; mkdir -p "$OUT"
export JULIA_PKG_OFFLINE=true MPLCONFIGDIR=$OUT/mpl

echo "-- python (pandas + matplotlib)"
"$PYENV/bin/python" $ROOT/experiments/interfaces/python/app.py "$CSV" "$OUT/py.png" >/dev/null 2>&1   # matplotlib's font cache
for i in $(seq "$RUNS"); do
    s=$(date +%s.%N)
    p=$("$PYENV/bin/python" $ROOT/experiments/interfaces/python/app.py "$CSV" "$OUT/py.png" 2>&1 >/dev/null)
    e=$(date +%s.%N)
    echo "$p | wall $(echo "$e - $s" | bc)"
done

for J in "$STOCK" "$PATCHED"; do
    echo "-- julia $J, form (a)"
    for i in $(seq "$RUNS"); do
        s=$(date +%s.%N)
        p=$(flock "$LOCK" nice -n 10 "$J" --startup-file=no --project=env scripts/report_script.jl "$CSV" "$OUT/jl.png" 2>&1 >/dev/null | tail -1)
        e=$(date +%s.%N)
        echo "$p" | awk -v s="$s" -v e="$e" '{
            for (i = 1; i <= NF; i++) { if ($i == "start") st = $(i+1); if ($i == "end") en = $(i+1) }
            line = $0; sub(/^start [^ ]+ /, "", line); sub(/ end [^ ]+$/, "", line)
            printf "startup %.3f | %s | exit %.3f | wall %.3f\n", st - s, line, e - en, e - s }'
    done
done
