#!/bin/bash
# The report under loads (rows 7, 8): Plain (form a′) and Trait (form b), one coherent environment (env_loads/).
# JFLAGS="-J <sysimage>" for the TraitWorld system image (experiments/sysimage); SETS= to choose the load sets.
# env_loads must be precompiled by each Julia (and each system image) first.
ROOT=${TW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
cd $ROOT/TraitReport
L=${JULIA_LOCK:-$TMPDIR/julia.lock}
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
CSV=$ROOT/experiments/interfaces/App/data/sample.csv
J=${J:-$ROOT/julia-1.13/julia}
for set in ${SETS:-"" "REPL" "OffsetArrays StatsBase Unitful" "IntervalArithmetic Distributions Interpolations StaticArrays" "REPL CairoMakie OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays"}; do
  for w in ${FORMS:-Plain Trait}; do
    JULIA_LOAD_PATH="$ROOT/TraitReport/env_loads:@stdlib" flock $L nice -n 10 timeout 1800 $J ${JFLAGS:-} --startup-file=no scripts/report_loads.jl $w $CSV $TMPDIR/l.png $set 2>&1 | grep -E "^(Plain|Trait|Tables)|ERROR|rror:" | head -3
  done
done
