# Row 8: compiled code of the report's libraries lost to other packages' loads, and code compiled
# by the work, per library and per owner (native, or the facts policy's cache).
#
#     JULIA_LOAD_PATH="env_loads:@stdlib" julia scripts/invalidated.jl Tables|PlainTables none|before|after <csv> [packages...]
#
# Counts valid CodeInstances of methods of TraitCSV, TraitTables, TraitMakie, PlainTables (and
# TraitWorld) at three points: after loading everything, after the loads in `after` order, and
# the new ones the report's work compiles.
const which, order, csv = ARGS[1], ARGS[2], ARGS[3]
pk = ARGS[4:end]
loadpkgs() = for p in pk; Core.eval(Main, Meta.parse("using $p")); end
order == "before" && loadpkgs()
which == "Tables" ? (@eval using TraitCSV, TraitTables, TraitMakie) : (@eval using PlainTables, TraitMakie)
const ROOTS = (:TraitCSV, :TraitTables, :TraitMakie, :PlainTables, :TraitWorld)
function cis()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci); isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    out
end
function tally(f = ci -> true)
    d = Dict{Tuple{Symbol,Symbol},Int}()
    for ci in cis()
        f(ci) || continue
        ci.max_world == typemax(UInt) || continue
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        r = nameof(Base.moduleroot(mi.def.module))
        r in ROOTS || continue
        k = (r, ci.owner === nothing ? :native : :policy)
        d[k] = get(d, k, 0) + 1
    end
    return sort!(collect(d))
end
fmt(t) = join(["$(r)/$(o) $(n)" for ((r, o), n) in t], ", ")
println("valid after loading: ", fmt(tally()))
if order == "after"
    loadpkgs()
    println("valid after the loads: ", fmt(tally()))
end
old = Set(cis())
png = joinpath(get(ENV, "TMPDIR", tempdir()), "inv.png")
if which == "Tables"
    w = @eval () -> (t = TraitCSV.read($csv); TraitTables.summary_text(t); x = TraitTables.floats(t, TraitTables.colnames(t)[1]);
                     f = TraitMakie.hist(x; bins = 24, title = "i", size = (1200, 800)); TraitMakie.vlines!(f, sum(x) / length(x); color = :red); TraitMakie.save($png, f))
else
    w = @eval () -> (t = PlainTables.readcsv($csv); PlainTables.summary_text(t); x = PlainTables.floats(t, PlainTables.colnames(t)[1]);
                     f = TraitMakie.hist(x; bins = 24, title = "i", size = (1200, 800)); TraitMakie.vlines!(f, sum(x) / length(x); color = :red); TraitMakie.save($png, f))
end
t = @elapsed Base.invokelatest(w)
println("work ", round(1000t; digits = 1), " ms; compiled by the work: ", fmt(tally(ci -> !(ci in old))))
