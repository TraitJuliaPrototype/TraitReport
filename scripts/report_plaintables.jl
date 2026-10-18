# Form (pt) of TraitReport, the fair baseline of form (t): the same plain script over PlainTables
# (TraitTables and TraitCSV without traits, the same workload) and TraitMakie.
#
#     julia --startup-file=no --project=env_pt scripts/report_plaintables.jl <csv> <out.png> [String15]
T = [time()]
using PlainTables, TraitMakie
const STRINGS = get(ARGS, 3, "") == "String15"
STRINGS && @eval using InlineStrings: String15
push!(T, time())
t = STRINGS ? readcsv(ARGS[1]; types = Type[Int, Float64, String15, String]) : readcsv(ARGS[1])
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
