# Row 11: a strings column. Form (t): InlineStrings loaded (TraitCSV's conformance for String15
# arrives in an extension), then a file with a strings column read with String15 among the
# candidate types. Form (c): CSV.jl with DataFrames (CSVInlineStringsExt).
#
#     JULIA_LOAD_PATH="env_loads:@stdlib" julia scripts/row11.jl Tables|CSV
const which = ARGS[1]
path = joinpath(get(ENV, "TMPDIR", tempdir()), "row11.csv")
open(path, "w") do f
    println(f, "name,x,n")
    for i in 1:200
        println(f, "item", i, ",", 0.5i, ",", i)
    end
end
t0 = time()
if which == "Tables"
    @eval using TraitCSV, TraitTables, InlineStrings
    t1 = time()
    r = @eval () -> TraitTables.summary_text(TraitCSV.read($path; types = [Int[], Float64[], InlineStrings.String15[], String[]]))
else
    @eval using CSV, DataFrames
    t1 = time()
    r = @eval () -> describe(CSV.read($path, DataFrame))
end
t = @elapsed s = Base.invokelatest(r)
println(rpad(which, 8), "using ", round(t1 - t0; digits = 2), " s, first read with a strings column ", round(1000t; digits = 1), " ms")
which == "Tables" && print(s)
