# TraitReport

A data report in a fresh Julia session: read a CSV file into a DataFrame, summarize its columns, plot a histogram to a PNG. This is the third demonstrator. It measures the trait world where Julia users feel time to first plot most, against pandas and matplotlib doing the same task.

Status: started in session 26 (2026-10-17). Form (a), the ordinary script, is measured. Forms (b) and (c) are planned. The design is in the design repository (`../writeup/notes/`). How the trait world compiles CSV and DataFrames is case D of `../writeup/notes/3-wrapping.md` ("Four cases"), which no measurement has covered yet.

## The task

It is the task of the Python baseline, `../experiments/interfaces/python/app.py` (session 21):
- read `../experiments/interfaces/App/data/sample.csv` (200 rows, 3 `Float64` columns) into a DataFrame;
- per column: mean, sample standard deviation, min, max and sum, printed;
- a 24-bin histogram of the first column, with a vertical line at its mean, titled with the file name;
- saved as a 1200 × 800 PNG;
- timed from process start to process exit, in a fresh process.

TraitMakie has no `barplot` yet, so form (a) draws the histogram as a step line.

## The three forms

- **(a) An ordinary script** (`scripts/report_script.jl`): `using CSV, DataFrames, Statistics, TraitMakie` at the prompt, then plain calls. Only TraitMakie's own code is trait-world code. This is what a user writes today.
- **(b) A trait-world report:** a small trait module `ReportCore` whose functions call CSV, DataFrames and TraitMakie directly, with a precompile workload from file to PNG. Under wrapping by facts, CSV's and DataFrames' code reached from it is compiled under the facts policy and kept in `ReportCore`'s image. A later load can then discard it only where the loaded package is a stakeholder of one of its facts, or brings a pirate that wins at one. This is case D of the design, measured.
- **(b′) TraitCSV:** a CSV reader written in the trait world, the principled fix for what (b) can only contain (below).
- **(c) A trimmed binary** of (b): the CSV binary of `../writeup/explorations/aot-under-facts.md` §4. Session 25 deferred it.

## What it demonstrates

**Where Julia stands today (form (a), measured below):** 4.9–5.1 s against Python's 0.60 s. The cost comes from three places:
- **Plain Julia's invalidation of ordinary code.** CSV reads the file in 0.19 s when loaded alone. With DataFrames loaded, in either order, the first read takes 2.5 s. DataFrames loads InlineStrings, which activates CSV's own extension `CSVInlineStringsExt`. That extension adds methods to CSV's internal functions (`_settledstringtype`, `_lazyeltype`, `_materializecolumn`), which invalidate CSV's precompiled read path. InlineStrings' `thisind(::InlineString, ::Int)` is among the invalidating methods too; it is the method behind session 20's 8.4 s Makie recompilation.
- **TraitWorld invalidating ordinary code.** TraitWorld defines `Base.show(io::IO, T::Type{<:CObj})` and `Base.show(io::IO, T::Type{<:TObj})`. These methods are no pirates, since TraitWorld owns the types. But they invalidate every caller compiled for `show(::IO, ::Type)`, CSV's `parsecolchunk!` included, and Base's exit hooks. Together they cost 1.0 s. A trait-world package must not slow down the plain world.
- **Loading.** The imports take 0.82 s on stock Julia (Python: 0.41 s). They take 1.40 s on the patched build, where TraitMakie's image alone loads in 0.69 s against 0.23 s stock. The patched build's images carry the policy's native code (Julia piece 5).

**The trait design predicts** (form (b), patched build):
- **Loads cannot slow down the report's compiled code.** That includes CSV's read path. `CSVInlineStringsExt`'s methods apply at signatures with InlineStrings' types, so they can change a fact of the report only if the report reads strings. For a numeric file they change none. The same goes for `thisind(::InlineString, ::Int)`.
- **Time from process start to PNG of about 1 s:**
  - startup 0.10 s and imports about 0.8 s;
  - reading, summarizing and plotting in tens of milliseconds;
  - no exit cost.
- **About 1 s is the bar** (the user, session 26: "I consider 1s to be fine relative to python"). Reaching Python's 0.6 s would need cheaper loading, of the patched images and of DataFrames itself (0.36 s alone). Form (c) shows the binary form, where the session's costs do not arise.

**TraitCSV, the principled fix** (the user, session 26: "consider if a TraitCSV could fix them in a principled manner"):
- **What goes wrong today:** CSV supports InlineStrings by a package extension that adds methods to CSV's own internal functions. Loading InlineStrings, for any reason, widens those functions and discards CSV's compiled read path, also for files without a single string column.
- **Under the policy alone (form (b)):** CSV's calls such as `_settledstringtype(T, maxlen)` take a type as a value, so they are run-time sites and record no fact. The extension's methods should then invalidate nothing. But CSV stays code written without traits: its precompiled native code is still discarded for every ordinary caller, and what the read path compiles is decided by CSV's internals, not by a bound.
- **In the trait world:** the column element types a reader can produce are a trait, say `CellType`, with operations to parse a cell and to build a column. A reader is bounded by it. A string type that wants to be read conforms: `@implement CellType InlineString15` in InlineStrings or a small glue package. A conformance is a method of the conformance registry (one method per conformance, `@max_methods 1`), so adding one invalidates no entry, and the reader compiled for `Float64` columns has no fact at InlineStrings' types. This is what package extensions become in a trait-world ecosystem: conformances, which cannot discard other keys' code.
- **How much to build:** a reader for delimited numeric and string columns, with type detection, a `ColTable`-style result that DataFrames can take, and `CellType` conformances for `Float64`, `Int`, `String` and one InlineStrings type. Hundreds of lines, not CSV.jl's breadth.

## Measurements

The harness is `scripts/measure.sh`: fresh processes, the Julia binary called directly (not through juliaup), niced, one Julia job at a time. Machine: the shared workstation, idle at the time.

| # | What | Python | Prediction | Measured (session 26, form (a); stock 1.13.2, patched in brackets) |
|---|---|---|---|---|
| 1 | process start to exit, task done | 0.60–0.61 s | forms (b) and (b′) about 1 s (the bar); form (c) under 0.2 s | 4.87–5.11 s (5.92–6.02 s) |
| 2 | phases: startup, imports, read, summarize, plot and PNG, exit | –, 0.41, 0.001, 0.001, 0.10, – | 0.10, ~0.8, ≤ 0.05 together for the next three, ~0 | 0.10, 0.75–0.79, 3.48–3.66, 0.064–0.068, 0.11, 0.36–0.38 (0.10, 1.44–1.49, 3.81–3.89, 0.065–0.07, 0.16, 0.35) |
| 3 | CSV's first read: CSV alone; with DataFrames before or after | | form (b): the same with or without DataFrames | `CSV.File`: 0.19 s alone; 2.46–2.53 s with DataFrames in either order |
| 4 | invalidations of ordinary code by TraitWorld's own methods | | none | +1.0 s on the first read; without the two `show(::IO, ::Type{…})` methods, read 2.64 s, exit 0.18 s, total 3.84 s |
| 5 | imports, per package: CSV, DataFrames, TraitWorld, TraitMakie, all | 0.41 s (pandas and matplotlib) | patched no slower than stock | 0.15, 0.36, 0.12, 0.23, 0.82 s (0.15, 0.39, 0.12, 0.69, 1.40 s) |
| 6 | exit time | – | ~0 | 0.36–0.38 s: TraitWorld's view-cache flush (0.14 s with TraitMakie alone) and exit hooks that TraitWorld's methods invalidated |
| 7 | load-order independence: CairoMakie, ChurnStorm, BasePirate, the g2all stack loaded before, after or not at all | | form (b): spread under 10% | not yet |
| 8 | policy CodeInstances of the report (CSV's and DataFrames' code included) lost by those loads | | 0 | not yet |
| 9 | trimmed binary, form (c): size, process start to PNG | | runs; a few MB; under 0.2 s | not yet (deferred, session 25) |
| 10 | a 10⁶-row file: read and plot, after the first call | pandas | within 2× of pandas | not yet |
| 11 | a strings column: what `CSVInlineStringsExt` then invalidates in form (b); what a new `CellType` conformance invalidates in form (b′) | | (b) only the facts at InlineStrings' types; (b′) nothing | not yet |

**Success:**
- row 1 for form (b) or (b′) at or under 1 s on the patched build;
- rows 3, 7 and 8 show that loads cannot slow the report down;
- row 4 is zero.

## Order of work

1. **TraitWorld stops invalidating ordinary code (rows 4, 6).** Drop the two `show(::IO, ::Type{…})` methods and print trait objects' types another way. Make the view-cache flush cost nothing when nothing is new. These are fixes in TraitWorld, not workarounds.
2. **Form (b),** `ReportCore` with a workload, on the patched build (rows 1–3, 7, 8).
3. **The patched images' load time (row 5):** why TraitMakie's image loads in 0.69 s on the patched build against 0.23 s on stock. This is Julia work on piece 5.
4. **Form (b′), TraitCSV,** if form (b) leaves CSV's costs in place, or as the ecosystem's shape regardless (row 11).
5. **`barplot` in TraitMakie,** so that the plot matches Python's.
6. **Form (c),** the binary, when binaries are taken up again.

**Not planned:** a precompile workload in `CSVInlineStringsExt`. It would be a workaround: it fixes form (a) for this pair of packages only, and it belongs to CSV.

**Running on the shared machine:** one Julia job at a time, niced; juliac builds alone, under the memory guard.
