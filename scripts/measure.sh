#!/bin/bash
# Fresh-process timings of TraitReport against the Python baseline.
#
#     scripts/measure.sh [runs] [forms]      # default 3 runs; forms "a b" ("p": the plain package, form (a′))
#
# Python:  pandas + matplotlib, ../experiments/interfaces/python/app.py, venv at $PYENV.
# Julia:   form (a) scripts/report_script.jl (env/), form (a′) scripts/report_plain.jl (env_p/),
#          form (t) scripts/report_tables.jl (env_t/: TraitCSV, TraitTables, TraitMakie),
#          form (pt) scripts/report_plaintables.jl (env_pt/: PlainTables, the same without traits),
#          form (b) scripts/report_traits.jl (env_b/),
#          on stock 1.13.2 and on the patched build, called by the binary, not through juliaup.
# Each environment must be precompiled first by each Julia (the patched build keeps its own images).
# The scripts print the absolute times of their marks; startup and exit are taken against this
# script's wall clock. The machine is shared: one Julia job at a time (flock), niced.
set -u
cd "$(dirname "$0")/.."
RUNS=${1:-3}
FORMS=${2:-"a b"}
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

# phases from the marks "T t1 t2 ...": startup = t1 - s, then the differences, exit = e - last
phases() {
    awk -v s="$1" -v e="$2" -v names="$3" '/^T / {
        n = split(names, nm, " ")
        printf "startup %.3f", $2 - s
        for (i = 3; i <= NF; i++) printf " | %s %.3f", nm[i-2], $i - $(i-1)
        printf " | exit %.3f | wall %.3f\n", e - $NF, e - s }'
}

for J in ${JULIAS:-"$STOCK" "$PATCHED"}; do
    for form in $FORMS; do
        if [ "$form" = a ]; then env=env; script=scripts/report_script.jl; names="imports read summarize plot+PNG"
        elif [ "$form" = p ]; then env=env_p; script=scripts/report_plain.jl; names="imports report"
        elif [ "$form" = pt ]; then env=env_pt; script=scripts/report_plaintables.jl; names="imports read summarize plot+PNG"
        elif [ "$form" = t ]; then env=env_t; script=scripts/report_tables.jl; names="imports read summarize plot+PNG"
        else env=env_b; script=scripts/report_traits.jl; names="imports report"; fi
        echo "-- julia $J, form ($form)"
        for i in $(seq "$RUNS"); do
            s=$(date +%s.%N)
            p=$(flock "$LOCK" nice -n 10 "$J" ${JFLAGS:-} --startup-file=no --project=$env $script "$CSV" "$OUT/jl_$form.png" 2>&1 >/dev/null)
            e=$(date +%s.%N)
            echo "$p" | grep -v '^T ' | head -3
            echo "$p" | phases "$s" "$e" "$names"
        done
    done
done
