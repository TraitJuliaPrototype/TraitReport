"""
    PlainTables

TraitTables and TraitCSV without traits (TraitReport's fair baseline, form (p2)): the same table,
reader and summaries as plain Julia. Columns are a `Vector{AbstractVector}`; each column's code
runs behind a function barrier, compiled per column type; the candidate column types are types.
"""
module PlainTables
using PrecompileTools: @compile_workload
export Table, ncol, nrow, colnames, column, addcolumn!, select, rows, head, sortby, floats, ColSummary,
       describe, summary_text, readcsv, parsecsv

struct Table
    names::Vector{String}
    cols::Vector{AbstractVector}
end
table(pairs::Pair...) = (t = Table(String[], AbstractVector[]); for (n, v) in pairs; addcolumn!(t, String(n), v); end; t)
ncol(t::Table) = length(t.cols)
nrow(t::Table) = isempty(t.cols) ? 0 : length(t.cols[1])
colnames(t::Table) = copy(t.names)
function colindex(t::Table, name::String)
    k = findfirst(==(name), t.names)
    k === nothing && throw(ArgumentError("no column \"$name\"; the columns are $(join(t.names, ", "))"))
    return k
end
column(t::Table, name::String) = t.cols[colindex(t, name)]
function addcolumn!(t::Table, name::String, c::AbstractVector)
    name in t.names && throw(ArgumentError("a column \"$name\" exists already"))
    isempty(t.cols) || length(c) == nrow(t) ||
        throw(DimensionMismatch("column \"$name\" has $(length(c)) rows, the table $(nrow(t))"))
    push!(t.names, name)
    push!(t.cols, c)
    return t
end
select(t::Table, names::Vector{String}) = Table(copy(names), AbstractVector[t.cols[colindex(t, n)] for n in names])
take(c::AbstractVector, idx::Vector{Int}) = c[idx]
rows(t::Table, idx::Vector{Int}) = Table(copy(t.names), AbstractVector[take(c, idx) for c in t.cols])
head(t::Table, n::Int) = rows(t, collect(1:min(n, nrow(t))))
sortby(t::Table, name::String) = rows(t, sortperm(column(t, name))::Vector{Int})

function floats(c::AbstractVector)
    v = Vector{Float64}(undef, length(c))
    for i in eachindex(c, v)
        v[i] = Float64(c[i])
    end
    return v
end
floats(t::Table, name::String) = floats(column(t, name))::Vector{Float64}

struct ColSummary
    name::String
    eltype::String
    n::Int
    numeric::Bool
    mean::Float64
    std::Float64
    min::Float64
    max::Float64
    sum::Float64
    ndistinct::Int
end
function numsummary(c::AbstractVector{<:Real}, name::String)
    n = length(c)
    s = 0.0
    lo, hi = Inf, -Inf
    for x in c
        s += x; lo = min(lo, x); hi = max(hi, x)
    end
    m = s / n
    q = 0.0
    for x in c
        q += (x - m)^2
    end
    return ColSummary(name, string(eltype(c)), n, true, m, n > 1 ? sqrt(q / (n - 1)) : NaN, lo, hi, s, 0)
end
summarize(c::AbstractVector{<:Real}, name::String) = isempty(c) ? ColSummary(name, "", 0, false, NaN, NaN, NaN, NaN, NaN, 0) : numsummary(c, name)
summarize(c::AbstractVector, name::String) =
    ColSummary(name, string(eltype(c)), length(c), false, NaN, NaN, NaN, NaN, NaN, length(Set(c)))
describe(t::Table) = ColSummary[summarize(t.cols[k], t.names[k])::ColSummary for k in eachindex(t.cols)]

function summary_text(t::Table)
    io = IOBuffer()
    for s in describe(t)
        if s.numeric
            println(io, rpad(s.name, 6), " mean ", round(s.mean; digits = 4), "  std ", round(s.std; digits = 4),
                    "  min ", s.min, "  max ", s.max, "  sum ", round(s.sum; digits = 4))
        else
            println(io, rpad(s.name, 6), " ", s.eltype, ", ", s.ndistinct, " distinct of ", s.n)
        end
    end
    return String(take!(io))
end

# --- the reader ---------------------------------------------------------------------------------

parsecell(::Type{T}, s::String, a::Int, b::Int) where {T<:Union{Int,Float64}} = tryparse(T, SubString(s, a, b))
parsecell(::Type{String}, s::String, a::Int, b::Int) = String(SubString(s, a, b))
parsecell(::Type{T}, s::String, a::Int, b::Int) where {T<:AbstractString} = b - a + 1 <= sizeof(T) - 1 ? T(SubString(s, a, b)) : nothing

"Header names and, per column, the byte ranges of its cells (quotes stripped). Blank lines are skipped."
function scan(s::String, delim::UInt8)
    b = codeunits(s)
    n = length(b)
    names = String[]
    spans = Vector{UnitRange{Int}}[]
    row = UnitRange{Int}[]
    i = 1
    header = true
    while i <= n
        # one row
        empty!(row)
        while true
            if i <= n && b[i] == UInt8('"')
                a = i + 1
                i = a
                while i <= n && !(b[i] == UInt8('"') && (i == n || b[i+1] != UInt8('"')))
                    i += b[i] == UInt8('"') ? 2 : 1
                end
                push!(row, a:i-1)
                i += 1
            else
                a = i
                while i <= n && b[i] != delim && b[i] != UInt8('\n') && b[i] != UInt8('\r')
                    i += 1
                end
                push!(row, a:i-1)
            end
            if i <= n && b[i] == delim
                i += 1
                continue
            end
            break
        end
        while i <= n && (b[i] == UInt8('\r') || b[i] == UInt8('\n'))
            i += 1
        end
        length(row) == 1 && isempty(row[1]) && continue          # a blank line
        if header
            append!(names, [String(SubString(s, first(r), last(r))) for r in row])
            append!(spans, [UnitRange{Int}[] for _ in row])
            header = false
        else
            length(row) == length(names) ||
                throw(ArgumentError("a row has $(length(row)) cells, the header $(length(names)): $(repr(SubString(s, first(row[1]), max(last(row[end]), first(row[1])))))"))
            for k in eachindex(row)
                push!(spans[k], row[k])
            end
        end
    end
    return names, spans
end

"Parse every cell as a `T`; the column, or `nothing` at the first cell that does not fit."
function fillcolumn(::Type{T}, s::String, spans::Vector{UnitRange{Int}}) where {T}
    c = T[]
    sizehint!(c, length(spans))
    for r in spans
        x = parsecell(T, s, first(r), last(r))
        x === nothing && return nothing
        push!(c, x)
    end
    return c
end

const DEFAULTTYPES = DataType[Int, Float64, String]
function parsecsv(text::AbstractString; delim::Union{Char,UInt8} = ',', types::Vector{DataType} = DEFAULTTYPES)
    s = String(text)
    names, spans = scan(s, UInt8(delim))
    t = Table(String[], AbstractVector[])
    for k in eachindex(names)
        col = nothing
        for T in types
            col = fillcolumn(T, s, spans[k])
            col === nothing || break
        end
        col === nothing && throw(ArgumentError("column \"$(names[k])\": no column type fits its cells"))
        push!(t.names, names[k])
        push!(t.cols, col)
    end
    return t
end
readcsv(path::AbstractString; kw...) = parsecsv(read(path, String); kw...)

@compile_workload begin
    t = table("x" => [0.5, 1.5, 2.5], "n" => [3, 1, 2], "s" => ["b", "a", "c"])
    summary_text(t)
    summary_text(sortby(t, "n"))
    head(select(t, ["x", "s"]), 2)
    floats(t, "x"); floats(t, "n")
    t2 = parsecsv("a,b,c\n1,2.5,x\n2,3.5,\"y, z\"\n")
    summary_text(t2)
    path = tempname() * ".csv"
    write(path, "x,y\n0.1,1\n0.2,2\n")
    summary_text(readcsv(path))
    rm(path; force = true)
end

end
