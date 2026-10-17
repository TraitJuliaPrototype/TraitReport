# Rows 7 and 8: the report's work after other packages were loaded first (fresh process).
#
#     JULIA_LOAD_PATH="<env with the report>:<env with the extra packages>:@stdlib" \
#         julia scripts/report_loads.jl Plain|Trait <csv> <png> [packages to load first...]
#
# Prints the load time and the report's first call. `Plain` is form (a′), `Trait` form (b),
# `Tables` form (t) (TraitCSV, TraitTables, TraitMakie), `PlainTables` form (pt) (the same without traits).
const which = ARGS[1]
csv, png = ARGS[2], ARGS[3]
pk = ARGS[4:end]
t0 = time()
for p in pk
    Core.eval(Main, Meta.parse("using $p"))
end
t1 = time()
if which == "Plain"
    @eval using PlainReport
    r = () -> PlainReport.report(csv, png; io = IOBuffer())
elseif which == "Trait"
    @eval using TraitReport
    r = () -> TraitReport.report(csv, png; io = IOBuffer())
elseif which == "Tables"
    @eval using TraitCSV, TraitTables, TraitMakie
    r = @eval () -> begin
        t = TraitCSV.read($csv)
        TraitTables.summary_text(t)
        x = TraitTables.floats(t, TraitTables.colnames(t)[1])
        f = TraitMakie.hist(x; bins = 24, title = "loads", size = (1200, 800))
        TraitMakie.vlines!(f, sum(x) / length(x); color = :red)
        TraitMakie.save($png, f)
    end
else
    @eval using PlainTables, TraitMakie
    r = @eval () -> begin
        t = PlainTables.readcsv($csv)
        PlainTables.summary_text(t)
        x = PlainTables.floats(t, PlainTables.colnames(t)[1])
        f = TraitMakie.hist(x; bins = 24, title = "loads", size = (1200, 800))
        TraitMakie.vlines!(f, sum(x) / length(x); color = :red)
        TraitMakie.save($png, f)
    end
end
t2 = time()
t = @elapsed Base.invokelatest(r)
println(rpad(which, 12), rpad(isempty(pk) ? "(none)" : join(pk, ","), 70), " loads ", round(t1 - t0; digits = 2), " s, using ", round(t2 - t1; digits = 2), " s, work ", round(1000t; digits = 1), " ms")
