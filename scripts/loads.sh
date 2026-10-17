#!/bin/bash
# The report under loads (rows 7, 8): Plain (form a′) and Trait (form b), one coherent environment (env_loads/).
# JFLAGS="-J <sysimage>" for the TraitWorld system image (experiments/sysimage); SETS= to choose the load sets.
# env_loads must be precompiled by each Julia (and each system image) first.
cd /home/hellmann/Repos/julia-trait-bound/TraitReport
L=/tmp/claude-1000/-home-hellmann-Repos-julia-trait-bound/6c8f1719-6fc1-42fb-a8dc-c45452eef443/scratchpad/julia.lock
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4
CSV=/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv
J=${J:-/home/hellmann/Repos/julia-trait-bound/julia-1.13/julia}
for set in ${SETS:-"" "REPL" "OffsetArrays StatsBase Unitful" "IntervalArithmetic Distributions Interpolations StaticArrays" "REPL CairoMakie OffsetArrays StatsBase Unitful IntervalArithmetic Distributions Interpolations StaticArrays"}; do
  for w in Plain Trait; do
    JULIA_LOAD_PATH="/home/hellmann/Repos/julia-trait-bound/TraitReport/env_loads:@stdlib" flock $L nice -n 10 timeout 1800 $J ${JFLAGS:-} --startup-file=no scripts/report_loads.jl $w $CSV $TMPDIR/l.png $set 2>&1 | grep -E "^(Plain|Trait)|ERROR|rror:" | head -3
  done
done
