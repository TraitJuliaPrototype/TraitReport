# Form (a) of TraitReport: the Python baseline's task as an ordinary Julia script.
#
#     julia --startup-file=no --project=env scripts/report_script.jl <csv> <out.png>
#
# The task of experiments/interfaces/python/app.py: read the CSV into a DataFrame; per column mean,
# sample standard deviation, min, max and sum; a 24-bin histogram of the first column with a
# vertical line at its mean, titled with the file name, saved as a 1200 x 800 PNG.
# TraitMakie has no barplot yet: the histogram is drawn as a step line.
#
# Each phase is a top-level statement, so it is compiled when it is reached and its time includes
# its compilation. Prints the absolute times of its marks, from which the harness derives the
# phases and the process's startup and exit times against its own wall clock (scripts/measure.sh).
T = [time()]
using CSV, DataFrames, Statistics, TraitMakie
push!(T, time())
df = CSV.read(ARGS[1], DataFrame)
push!(T, time())
for name in names(df)
    c = df[!, name]
    println(rpad(name, 6), " mean ", round(mean(c); digits=4), "  std ", round(std(c); digits=4),
            "  min ", minimum(c), "  max ", maximum(c), "  weighted ", round(sum(c); digits=4))
end
push!(T, time())
function histline(x)
    lo, hi = extrema(x); w = (hi - lo) / 24
    counts = zeros(24)
    for v in x; counts[clamp(floor(Int, (v - lo) / w) + 1, 1, 24)] += 1; end
    sx = Float64[]; sy = Float64[]
    for i in 1:24; push!(sx, lo + (i-1)*w, lo + i*w); push!(sy, counts[i], counts[i]); end
    sx, sy, maximum(counts)
end
x = Vector{Float64}(df[!, 1])
sx, sy, cmax = histline(x)
f = lines(sx, sy; title = basename(ARGS[1]), size = (1200, 800))
m = mean(x)
lines!(f, [m, m], [0.0, cmax]; color = :red)
save(ARGS[2], f)
push!(T, time())
# raw times only: the harness subtracts (computing here would compile `diff` and `round` after the last mark)
println(stderr, "T ", T[1], " ", T[2], " ", T[3], " ", T[4], " ", T[5])
