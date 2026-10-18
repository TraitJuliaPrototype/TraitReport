# Form (t) of TraitReport: the task as a plain script over trait-world libraries, TraitCSV,
# TraitTables and TraitMakie, with no workload of its own (the libraries precompile their own code).
#
#     julia --startup-file=no --project=env_t scripts/report_tables.jl <csv> <out.png> [String15]
#
# With `String15`, InlineStrings is loaded and its `String15` is a candidate column type: TraitCSV's
# conformance for it arrives in a package extension. The histogram is of the first numeric column,
# missing cells left out. Each phase is a top-level statement, compiled when reached; prints raw
# times like report_script.jl.
T = [time()]
using TraitCSV, TraitTables, TraitMakie
const STRINGS = get(ARGS, 3, "") == "String15"
STRINGS && @eval using InlineStrings: String15
push!(T, time())
t = STRINGS ? TraitCSV.read(ARGS[1]; types = [Int[], Float64[], String15[], String[]]) : TraitCSV.read(ARGS[1])
push!(T, time())
print(summary_text(t))
push!(T, time())
name = numericnames(t)[1]
x = floats(t, name; skipmissing = true)
f = hist(x; bins = 24, title = basename(ARGS[1]), size = (1200, 800))
vlines!(f, sum(x) / length(x); color = :red)
save(ARGS[2], f)
push!(T, time())
println(stderr, "T ", T[1], " ", T[2], " ", T[3], " ", T[4], " ", T[5])
