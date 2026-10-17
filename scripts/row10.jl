# Row 10, trait side: form (t)'s work on a large file, best of 5 after a first call.
#     JULIA_LOAD_PATH="env_t:@stdlib" julia --startup-file=no scripts/row10.jl <csv>
using TraitCSV, TraitTables, TraitMakie
path = ARGS[1]
function work()
    t = TraitCSV.read(path)
    t1 = time()
    summary_text(t)
    x = floats(t, colnames(t)[1])
    f = hist(x; bins = 24, title = "row 10", size = (1200, 800))
    vlines!(f, sum(x) / length(x); color = :red)
    save(joinpath(get(ENV, "TMPDIR", tempdir()), "row10_jl.png"), f)
    return t1
end
for i in 1:6
    t0 = time(); t1 = work(); t2 = time()
    i > 1 && println("traits: read ", round(t1 - t0; digits = 3), " s, summary and plot ", round(t2 - t1; digits = 3), " s, total ", round(t2 - t0; digits = 3), " s")
end
