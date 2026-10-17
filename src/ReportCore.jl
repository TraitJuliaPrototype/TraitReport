# ReportCore: the trait module of form (b). The report's work runs in workers, compiled under
# the trait world's facts policy and kept in TraitReport's image: CSV's and DataFrames' code that
# the workers reach included (case D of writeup/notes/3-wrapping.md). A later load can discard
# that code only where the loaded package is a stakeholder of one of its dispatch facts, or brings
# a pirate that wins at one.
@trait_module module ReportCore
using TraitWorld
using CSV: CSV
using DataFrames: DataFrames, DataFrame
using Statistics: mean, std
using TraitMakie: TraitMakie
export Table, ncols, colname, column, Columns, columns, Job, ReportJob, summary_text, histogram_png, run_report

"What a report reads from a table: named columns of numbers."
@trait Table begin
    ncols(t::Table)::Int
    colname(t::Table, i::Int)::String
    column(t::Table, i::Int)::Vector{Float64}
end

# A DataFrame cannot conform: it is not deeply concrete (its columns are a Vector{AbstractVector}),
# so code bounded by `Table` would be compiled against columns of unknown type. The report converts
# it explicitly into a concrete table of its own (note "Types that only convert"); a trait-world CSV
# reader would produce such a table directly.
"Named columns of numbers: what the report reads a DataFrame into."
struct Columns
    names::Vector{String}
    cols::Vector{Vector{Float64}}
end
@implement Table Columns begin
    ncols(t) = length(t.cols)
    colname(t, i) = t.names[i]
    column(t, i) = t.cols[i]
end
"The DataFrame's columns as numbers (each converted, so a column of integers is read too)."
columns(df::DataFrame) = Columns(String.(DataFrames.names(df)), Vector{Float64}[convert(Vector{Float64}, c) for c in DataFrames.eachcol(df)])

"A report to make: the CSV file to read and the PNG file to write."
@trait Job begin
    @const input::String
    @const output::String
end
struct ReportJob
    input::String
    output::String
end
@implement Job ReportJob

"Per column: mean, sample standard deviation, min, max and sum, one line each."
function summary_text(t::Table)::String
    io = IOBuffer()
    for i in 1:ncols(t)
        c = column(t, i)
        println(io, rpad(colname(t, i), 6), " mean ", round(mean(c); digits = 4), "  std ", round(std(c); digits = 4),
                "  min ", minimum(c), "  max ", maximum(c), "  weighted ", round(sum(c); digits = 4))
    end
    return String(take!(io))
end

"A 24-bin histogram of column `i` with a vertical line at its mean, as a step line (no barplot yet)."
function histogram_png(t::Table, i::Int, title::String, out::String)::Nothing
    x = column(t, i)
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

"Read the job's CSV file into a DataFrame, plot its first column; the summary as text."
function run_report(j::Job)::String
    t = columns(CSV.read(j.input, DataFrame))
    s = summary_text(t)
    histogram_png(t, 1, basename(j.input), j.output)
    return s
end

end
