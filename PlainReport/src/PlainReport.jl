"""
    PlainReport

Form (a′) of TraitReport: the report as an ordinary package, without traits, with the whole task in
its precompile workload. It is the fair baseline for form (b): what plain Julia gets from a package
that precompiles exactly the work. Same functions as `ReportCore`, on a DataFrame directly.
"""
module PlainReport
using CSV: CSV
using DataFrames: DataFrames, DataFrame
using Statistics: mean, std
using TraitMakie: TraitMakie
export report

function summary_text(df::DataFrame)
    io = IOBuffer()
    for name in DataFrames.names(df)
        c = df[!, name]
        println(io, rpad(name, 6), " mean ", round(mean(c); digits = 4), "  std ", round(std(c); digits = 4),
                "  min ", minimum(c), "  max ", maximum(c), "  weighted ", round(sum(c); digits = 4))
    end
    return String(take!(io))
end

function histogram_png(x::Vector{Float64}, title::String, out::String)
    lo, hi = extrema(x)
    w = (hi - lo) / 24
    counts = zeros(24)
    for v in x
        counts[clamp(floor(Int, (v - lo) / w) + 1, 1, 24)] += 1
    end
    sx = Float64[]
    sy = Float64[]
    for k in 1:24
        push!(sx, lo + (k - 1) * w, lo + k * w)
        push!(sy, counts[k], counts[k])
    end
    f = TraitMakie.lines(sx, sy; title, size = (1200, 800))
    m = mean(x)
    TraitMakie.lines!(f, [m, m], [0.0, maximum(counts)]; color = :red)
    TraitMakie.save(out, f)
    return nothing
end

"Read `input` (CSV), print its columns' summary to `io`, plot the first column's histogram into `output` (PNG)."
function report(input::AbstractString, output::AbstractString; io::IO = stdout)
    df = CSV.read(String(input), DataFrame)
    print(io, summary_text(df))
    histogram_png(convert(Vector{Float64}, df[!, 1]), basename(String(input)), String(output))
    return output
end

# the precompile workload: the whole report, on a small file like the demonstration's
if ccall(:jl_generating_output, Cint, ()) == 1
    let dir = mktempdir()
        csv = joinpath(dir, "workload.csv")
        open(csv, "w") do f
            println(f, "x,y,z")
            for i in 1:50
                println(f, 0.1i, ",", sin(0.1i), ",", 2.5i)
            end
        end
        report(csv, joinpath(dir, "workload.png"); io = IOBuffer())
        rm(dir; recursive = true, force = true)
    end
end

end
