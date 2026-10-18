# A scripted interactive session (a correctness check, not a timing): fed line by line to a real
# REPL on a pseudo-terminal by scripts/session.sh, from the repository's root. A user reads the
# task's file, makes the report's plot, changes it, reads a second shape of data (missing cells, a
# strings column), adds a column of a type of their own, reads strings through InlineStrings (a
# conformance in TraitCSV's extension) and makes a plot of another type. Each `_ok` prints
# "CHECK <what> ok" or "... FAIL".
using TraitCSV, TraitTables, TraitMakie, TraitWorld
_ok(what, c) = println(c === true ? "CHECK $what ok" : "CHECK $what FAIL")
D = joinpath(pwd(), "data"); OUT = mktempdir(); png(n) = joinpath(OUT, n * ".png");
t = TraitCSV.read(joinpath(pwd(), "..", "experiments", "interfaces", "App", "data", "sample.csv"))
print(summary_text(t))
x = floats(t, "x");
f = figure(; title = "sample.csv", size = (1200, 800));
h = hist!(f, x; bins = 24)
vlines!(f, sum(x) / length(x); color = :red)
save(png("report"), f); _ok("the report's plot", filesize(png("report")) > 1000)
# the plot changed after it was made
h.bins = 12
h.color = :orange
save(png("changed"), f); _ok("a changed attribute", h.bars.width ≈ (maximum(x) - minimum(x)) / 12)
# a second shape of data: missing cells in four columns, a strings column
s = TraitCSV.read(joinpath(D, "sensors.csv"))
print(summary_text(s))
d = describe(s);
_ok("a second shape", [c.eltype for c in d] == ["Float64", "Union{Missing, Float64}", "Union{Missing, Float64}", "Union{Missing, Float64}", "Union{Missing, Int64}", "String"] && [c.nmissing for c in d] == [0, 16, 21, 16, 13, 0])
# a mistake teaches: missing cells, and the message names the fix
floats(s, "s1")
s1 = floats(s, "s1"; skipmissing = true);
_ok("missing cells left out", length(s1) == 484)
# a new data type: a column type of the user's own
struct Ramp; n::Int; end
TraitTables.nrows(r::Ramp) = r.n
TraitTables.cell(r::Ramp, i::Int) = 0.5 * i
@implement Column Ramp
addcolumn!(s, "ramp", Ramp(nrow(s)))
_ok("a new column type", describe(s)[end].mean == 0.5 * (nrow(s) + 1) / 2 && sortby(s, "ramp")["ramp"] isa Dynamic{Column})
# strings through InlineStrings: TraitCSV's conformance for String15 arrives in an extension
using InlineStrings
it = TraitCSV.read(joinpath(D, "items.csv"); types = [Int[], Float64[], String15[], String[]])
_ok("a strings column (String15)", describe(it)[1].eltype == "String15" && describe(it)[1].ndistinct == 200)
# a plot of another type: the numeric columns' means as bars, labelled
nm = numericnames(s); means = [c.mean for c in describe(s) if c.numeric];
b = barplot(collect(1.0:length(nm)), means; title = "means")
text!(b, collect(1.0:length(nm)), means .+ 0.2, nm; align = :center)
save(png("means"), b); _ok("a plot of another type", filesize(png("means")) > 1000 && length(b.axis.plots) == 2)
_ok("session done", true)
