# Rows 7 and 8: the report's work after other packages were loaded first (fresh process).
#
#     JULIA_LOAD_PATH="<env with the report>:<env with the extra packages>:@stdlib" \
#         julia scripts/report_loads.jl Plain|Trait <csv> <png> [packages to load first...]
#
# Prints the load time and the report's first call. `Plain` is form (a′), `Trait` form (b).
const which = ARGS[1]
csv, png = ARGS[2], ARGS[3]
pk = ARGS[4:end]
t0 = time()
for p in pk
    Core.eval(Main, Meta.parse("using $p"))
end
t1 = time()
which == "Plain" ? (@eval using PlainReport) : (@eval using TraitReport)
t2 = time()
r = which == "Plain" ? (() -> PlainReport.report(csv, png; io = IOBuffer())) : (() -> TraitReport.report(csv, png; io = IOBuffer()))
t = @elapsed Base.invokelatest(r)
println(rpad(which, 6), rpad(isempty(pk) ? "(none)" : join(pk, ","), 70), " loads ", round(t1 - t0; digits = 2), " s, using ", round(t2 - t1; digits = 2), " s, work ", round(1000t; digits = 1), " ms")
