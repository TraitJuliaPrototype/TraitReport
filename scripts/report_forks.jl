# Form (f) of TraitReport: the task as a plain script over the forks of CSV, DataFrames and Tables
# (demonstrator 4, ../forks: upstream's API with traits brought in) and TraitMakie. It prints the
# summary in TraitTables' format, so that its output can be compared with form (t)'s line by line.
#
#     julia --startup-file=no --project=env_f scripts/report_forks.jl <csv> <out.png> [String15]
T = [time()]
using CSV, DataFrames, TraitMakie
const STRINGS = get(ARGS, 3, "") == "String15"
STRINGS && @eval using InlineStrings: String15
push!(T, time())
df = CSV.read(ARGS[1], DataFrame; stringtype = STRINGS ? String15 : String)
push!(T, time())
function summary_line(io, name, c)
    k = findfirst(!ismissing, c)
    nmiss = count(ismissing, c)
    T = k === nothing ? "Missing" : nmiss > 0 ? "Union{Missing, $(typeof(c[k]))}" : string(typeof(c[k]))
    if k !== nothing && c[k] isa Real
        v = collect(Float64, skipmissing(c))                 # the statistics as TraitTables computes them
        s, lo, hi = 0.0, Inf, -Inf
        for y in v
            s += y; lo = min(lo, y); hi = max(hi, y)
        end
        m, q = s / length(v), 0.0
        for y in v
            q += (y - m)^2
        end
        print(io, rpad(name, 6), " mean ", round(m; digits = 4), "  std ", round(length(v) > 1 ? sqrt(q / (length(v) - 1)) : NaN; digits = 4),
              "  min ", lo, "  max ", hi, "  sum ", round(s; digits = 4))
    else
        print(io, rpad(name, 6), " ", T, ", ", length(Set(skipmissing(c))), " distinct of ", length(c))
    end
    println(io, nmiss > 0 ? string("  missing ", nmiss) : "")
end
for name in names(df)
    summary_line(stdout, name, df[!, name])
end
push!(T, time())
name = first(n for n in names(df) if eltype(df[!, n]) <: Union{Missing,Real} && any(!ismissing, df[!, n]))
x = collect(Float64, skipmissing(df[!, name]))
f = hist(x; bins = 24, title = basename(ARGS[1]), size = (1200, 800))
vlines!(f, sum(x) / length(x); color = :red)
save(ARGS[2], f)
push!(T, time())
println(stderr, "T ", T[1], " ", T[2], " ", T[3], " ", T[4], " ", T[5])
