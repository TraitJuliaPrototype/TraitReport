# TraitReport

A data report in a fresh Julia session: read a CSV file into a DataFrame, summarize its columns, plot a histogram to a PNG. This is the third demonstrator. It measures the trait world where Julia users feel time to first plot most, against pandas and matplotlib doing the same task.

Status (session 27, 2026-10-17): **form (t), a plain script over TraitCSV, TraitTables and TraitMakie, takes 0.52–0.56 s on the patched build** (Python: 0.58–0.69 s in the same run). Its fair baseline, form (pt), the same libraries written without traits, takes 0.50–0.52 s: in a fresh session, small precompiled libraries reach Python's time with or without traits. What traits add shows under loads and with new conformances (section "Form (t)" below): no compiled code of the three libraries is lost to nine other packages in either load order, while the plain version loses a third of its code and takes twice as long; a strings column with InlineStrings' `String15`, a conformance in an extension, costs 44 ms in each later session against CSV.jl's 3.9–5.0 s in every session. Forms (a), (a′) and (b) are from session 26; form (c), the binary, is deferred. The design is in the design repository (`../writeup/notes/`).

## The task

It is the task of the Python baseline, `../experiments/interfaces/python/app.py` (session 21):
- read `../experiments/interfaces/App/data/sample.csv` (200 rows, 3 `Float64` columns) into a DataFrame;
- per column: mean, sample standard deviation, min, max and sum, printed;
- a 24-bin histogram of the first column, with a vertical line at its mean, titled with the file name;
- saved as a 1200 × 800 PNG;
- timed from process start to process exit, in a fresh process.

TraitMakie has no `barplot` yet, so form (a) draws the histogram as a step line.

## The forms

- **(a) An ordinary script** (`scripts/report_script.jl`): `using CSV, DataFrames, Statistics, TraitMakie` at the prompt, then plain calls. Only TraitMakie's own code is trait-world code. This is what a user writes today.
- **(b) A trait-world report** (`src/ReportCore.jl`, `scripts/report_traits.jl`): a small trait module `ReportCore` whose functions call CSV, DataFrames and TraitMakie directly, with a precompile workload from file to PNG. A `DataFrame` cannot conform to a trait, since it is not deeply concrete: its columns are a `Vector{AbstractVector}`. So the report converts it explicitly into a concrete table of its own, named `Vector{Float64}` columns, which the bounds see. Under wrapping by facts, CSV's and DataFrames' code reached from it is compiled under the facts policy and kept in `ReportCore`'s image. A later load can then discard it only where the loaded package is a stakeholder of one of its facts, or brings a pirate that wins at one. This is case D of the design, measured.
- **(a′) A plain package, the fair baseline** (`PlainReport/`, `scripts/report_plain.jl`): the same report as an ordinary package without traits, with the whole task in its precompile workload. This is plain Julia's standard remedy for time to first X.
- **(t) TraitTables and TraitCSV** (`scripts/report_tables.jl`, `env_t/`; session 27): the task as a plain script with no workload of its own, over a table and a CSV reader written in the trait world (`../TraitTables`, `../TraitCSV`) and TraitMakie, which gained `hist`, `barplot` and `vlines!`. This replaces form (b′).
- **(pt) PlainTables, the fair baseline of (t)** (`PlainTables/`, `scripts/report_plaintables.jl`, `env_pt/`): TraitTables and TraitCSV with the traits taken out, as a careful Julia programmer writes them (columns as `Vector{AbstractVector}`, a function barrier per column, candidate column types as types), with the same workload, plotted by TraitMakie as well.
- **(c) A trimmed binary** of (b): the CSV binary of `../writeup/explorations/aot-under-facts.md` §4. Session 25 deferred it.

## What form (b) shows, and what it does not (session 26)

**On the patched build the plain package is as fast as form (b),** so form (b)'s 1 s demonstrates nothing traits-specific (the user's objection: "Wouldn't that be cheating?").

| | Python | plain package (a′) | trait report (b) |
|---|---|---|---|
| stock 1.13.2 | 0.60 s | 1.96–2.04 s (work 1.0 s) | 1.25–1.28 s (work 0.31 s) |
| patched | | **0.94–1.02 s** (work 0.07 s) | 1.03–1.05 s (work 0.06 s) |

- **The plain package's speed is Julia piece 5.** Without it (patched build, `JULIA_TW_KEEP_COMPILED=0` at its precompilation) the work takes 0.96–0.99 s. Stock Julia does not keep machine code that a downstream package compiled for upstream methods, here CSV's. So piece 5 helps plain Julia as much as the trait world: an argument for the upstream proposal.
- **Form (b)'s 55 ms came largely from CSV's own image.** CSV calls its heavy internals (`_parse`, `_prepareindexed`, the keyword `read`) at abstract types, so under the policy they are run-time sites and run CSV's native code.
- **Packages loaded first slow both forms down,** and the trait form more. Work, patched, one coherent environment (`scripts/report_loads.jl`):
  - after OffsetArrays, StatsBase and Unitful: plain 2.7–2.8 s; trait 5.3–5.7 s (1.7 s with the rule of facts at non-public functions off);
  - after IntervalArithmetic, Distributions, Interpolations and StaticArrays: plain 2.8 s; trait 5.5 s.

  Two causes:
  1. CSV's native code is invalidated, as in plain Julia.
  2. The policy's compiler code in TraitWorld's image fails validation, when packages that add methods to Base functions the Compiler calls at abstract types load before TraitWorld. It is then recompiled (`typeinf_local(::FactsInterp, …)`, 3.5 s). This is open-issues §1.3, decided as "the policy in the platform", and broader than the REPL case it was found with.
- **What would show the design** (decided by the user in session 26: TraitTables and TraitCSV, and DataFrames redesigned around traits): a table and a CSV reader written in the trait world. Their code is compiled for concrete column types and kept in their own images, so it is protected from loads whether or not the user's code has a workload. Package extensions such as `CSVInlineStringsExt` become conformances, which cannot discard other keys' code. This replaces form (b′) below with a larger form: TraitTables and TraitCSV.

## Form (t): TraitTables and TraitCSV (session 27)

**The libraries.**
- **TraitTables:** a `Column{T}` trait (`nrows`, `cell`), which every `Vector` conforms to; a `Table` of names and `Vector{Dynamic{Column}}` columns; selection, row selection, sorting, summaries, printing. A new schema compiles nothing; each column's code runs in workers compiled per column type.
- **TraitCSV:** a `CSVColumn{T} <: Column` trait (`parsecell!`, `emptylike`) for the columns the reader can produce, with conformances for `Vector{Int}`, `Vector{Float64}` and `Vector{String}`; InlineStrings' `String15` conforms in an extension. The reader tries candidate column types per column; each attempt runs a worker compiled per column type. A parsed column goes into the table as it is, through the supertrait.
- **The decision's `CellType` trait is `CSVColumn`:** the conforming values are the columns the reader parses into, not cell types, so that the conformance reads "a `Vector{String15}` can be a CSV column".

**Fresh session, patched build** (`scripts/measure.sh 3 "t pt p"`, `JULIAS=<patched>`; seconds):

| | startup | imports | read | summary | plot and PNG | exit | wall |
|---|---|---|---|---|---|---|---|
| Python (pandas, matplotlib) | | 0.39–0.41 | 0.001 | 0.001 | 0.10 | | 0.58–0.69 |
| (t) traits | 0.10 | 0.29–0.33 | 0.008 | 0.000 | 0.066–0.069 | 0.055–0.057 | **0.52–0.56** |
| (pt) the same without traits | 0.10 | 0.27–0.28 | 0.005 | 0.000 | 0.066–0.071 | 0.052–0.058 | **0.50–0.52** |
| (a′) PlainReport (CSV, DataFrames) | 0.10 | 0.71–0.72 | report 0.065 | | | 0.06 | 0.94–0.95 |

The same with view caches off (`JULIA_TW_VIEWCACHE=0`): 0.51–0.53 s, so the libraries' own images hold all the code.

**Under loads** (rows 7 and 8; `scripts/loads.sh` with `FORMS="Tables PlainTables"`, `scripts/invalidated.jl`; patched, no system image). The work: read, summary, histogram, PNG, in milliseconds, after packages loaded first:

| packages loaded first | (t) traits | (pt) without traits |
|---|---|---|
| none | 78 | 108 |
| REPL | 80 | 119 |
| OffsetArrays, StatsBase, Unitful | 76 | 102 |
| IntervalArithmetic, Distributions, Interpolations, StaticArrays | 79 | 147 |
| all of these, REPL and CairoMakie | 66 | 138 |

Compiled code lost, with all nine packages loaded before or after the libraries (valid CodeInstances of each library's methods; "policy": compiled under the facts policy):

| | before | after | the work then compiles |
|---|---|---|---|
| (t): TraitCSV 76, TraitTables 180, TraitMakie 289 | none lost | none lost | 1 method (`colnames`, missing from the workload; added since) |
| (pt): PlainTables 49 | 17 lost | 17 lost | 16 methods |
| TraitWorld's own native machinery (both forms) | about 190 of 2064 lost | about 200 lost | none for this work |

- **Session 26's form (b)** needed 5.3–5.7 s after OffsetArrays, StatsBase and Unitful, and 1.7 s with TraitWorld in the system image. Form (t) needs 76 ms without the system image: its work needs no new trait code, so the policy's compiler, whose code those loads invalidate (open-issues §1.3), is not needed.
- **The difference to the plain version is small in absolute terms** (tens of milliseconds). The seconds of session 26 came from CSV.jl's and DataFrames' code, not from tables in general.
- **TraitWorld's machinery loses native code** to these loads; that costs time only when new trait code is compiled after them, which the system image addresses.

**A strings column** (row 11; `scripts/row11.jl`, InlineStrings and the reader's conformance for `String15` loaded, a 200-row file with a strings column):

| | `using` | first read with a strings column, and summary |
|---|---|---|
| (t), first session | 0.21–0.22 s | 0.69–0.71 s: the policy compiles TraitTables' summary for the new key `Vector{String15}`, which neither image holds |
| (t), later sessions (view cache) | 0.23 s | **44 ms** |
| CSV.jl with DataFrames, every session | 0.57–0.94 s | 3.9–5.0 s |

**What this shows, and what it does not.**
- Shown: compiled code of trait-world libraries survives other packages' loads in any order; a package extension becomes a conformance that invalidates nothing; the combination of two libraries' code for a third package's type is compiled once and then cached.
- Not shown by the fresh-session time: plain Julia libraries of the same size and care are as fast. The comparison with CSV.jl and DataFrames is one of size and history as much as of design.
- Not yet measured: a 10⁶-row file (row 10); the binary (row 9); stock Julia (piece 5 is missing there, so the policy's code is compiled in each session).

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

The harness is `scripts/measure.sh`: fresh processes, the Julia binary called directly (not through juliaup), niced, one Julia job at a time. The scripts print raw timestamps and the harness subtracts, so no timing code is compiled inside the measured process. Machine: the shared workstation, idle at the time. A detached view-cache build inherits the harness's lock and can delay the next run (one run in session 26: 3.1 s before the script started); such runs are discarded.

| # | What | Python | Prediction | Measured (session 26; stock 1.13.2, patched in brackets) |
|---|---|---|---|---|
| 1 | process start to exit, task done | 0.58–0.62 s | forms (b) and (t) about 1 s (the bar); form (c) under 0.2 s | **(t) 0.52–0.56 s patched; (pt) 0.50–0.52 s** (session 27). (a) 3.79–3.87 s (3.73–3.93 s); **(b) 1.17–1.20 s (1.01–1.05 s)**. Before TraitWorld's fixes (rows 4, 5): (a) 4.87–5.11 s (5.92–6.02 s); (b) patched 1.72–1.77 s |
| 2 | phases: startup, imports, then the work, exit | –, 0.40, 0.10 together for read, summary and plot, – | 0.10, ~0.8, ≤ 0.05 for the work, ~0 | (a) 0.10, 0.76–0.80, read 2.62–2.65, summarize 0.07–0.12, plot and PNG 0.11, 0.09 (0.10, 0.71–0.74, 2.63–2.78, 0.12, 0.11, 0.07). **(b) 0.10, 0.71–0.72, work 0.27–0.29, 0.09 (0.10, 0.79–0.82, work 0.059–0.065, 0.066–0.069)**. On stock the work compiles the policy's code in each session (no piece 5) |
| 3 | CSV's first read: CSV alone; with DataFrames before or after | | form (b): the same with or without DataFrames | `CSV.File`: 0.19 s alone; 2.46–2.53 s with DataFrames in either order. Form (b), patched: the whole work 0.057 s with DataFrames and InlineStrings loaded; nothing of CSV's read path is recompiled |
| 4 | invalidations of ordinary code by TraitWorld's own methods | | none | fixed (TraitWorld 6239b1e, Julia db82407fa6): the two `show(::IO, ::Type{…})` methods cost 1.0 s on CSV's first read; they are now type printers registered with Julia's new registry (`Base.Experimental.register_type_printer`, patched build), which invalidates nothing |
| 5 | imports, per package: CSV, DataFrames, TraitWorld, TraitMakie, TraitReport, all | 0.40 s (pandas and matplotlib) | patched no slower than stock | fixed (TraitWorld, session 26). `using TraitReport`: 0.71–0.72 s stock, 0.79–0.82 s patched; form (a)'s set 0.76–0.80 s (0.71–0.74 s). The cause was not piece 5. TraitWorld's load hooks (piece 1) and package callback were compiled natively, so the loads they watch invalidated them, and they were compiled again four times per load: 0.82 s. They now run under the facts policy. Before: 0.82 s stock, 1.40 s patched for form (a)'s set; TraitMakie alone 0.23 s (0.69 s) |
| 6 | exit time | – | ~0 | 0.09 s (0.065 s), after TraitWorld's fix: the view cache's exit hook is registered only when something new was compiled. Before: 0.36–0.38 s |
| 7 | load-order independence: CairoMakie, ChurnStorm, BasePirate, the g2all stack loaded before, after or not at all | | form (b) and (t): spread under 10% | **form (t): 66–80 ms in every order** (within ±10% of 73 ms) without the system image; (pt) 102–147 ms (section "Form (t)"). Form (b): packages loaded first, work of form (b) against (a′), patched (`scripts/loads.sh`, `env_loads/`): none or REPL 54–56 ms (0.30–0.37 s); OffsetArrays, StatsBase, Unitful 5.3–5.7 s (2.7–2.8 s); IntervalArithmetic, Distributions, Interpolations, StaticArrays 5.5 s (2.8 s). **With TraitWorld in the system image** (`../experiments/sysimage`): 1.7 s, 1.7 s, and 2.2 s with all of them and CairoMakie (2.7–3.4 s). The rest is CSV's native code, invalidated as in plain Julia: TraitCSV's job. Not under 10% |
| 8 | policy CodeInstances of the report (CSV's and DataFrames' code included) lost by those loads | | 0 | form (t): **0** of TraitCSV's, TraitTables' and TraitMakie's code, native or policy, in either order; form (pt) loses 17 of 49 (section "Form (t)"). Form (b): CSV's heavy internals are run-time sites, not policy code |
| 9 | trimmed binary, form (c): size, process start to PNG | | runs; a few MB; under 0.2 s | not yet (deferred, session 25) |
| 10 | a 10⁶-row file: read and plot, after the first call | pandas | within 2× of pandas | not yet |
| 11 | a strings column: what `CSVInlineStringsExt` then invalidates in form (b); what a new `CSVColumn` conformance invalidates in form (t) | | (b) only the facts at InlineStrings' types; (t) nothing | form (t): nothing; first read with a `String15` column 44 ms (0.7 s in the first session, before the view cache); CSV.jl 3.9–5.0 s in every session |

**Success:**
- row 1 for form (b) or (b′) at or under 1 s on the patched build;
- rows 3, 7 and 8 show that loads cannot slow the report down;
- row 4 is zero.

## Order of work

1. *(Done, session 26.)* **TraitWorld stops invalidating ordinary code (rows 4, 6):** type printers through a new Julia registry instead of `show` methods; the view cache's exit hook only when something is new.
2. *(Built, session 26; rows 7, 8 open.)* **Form (b),** `ReportCore` with a workload (rows 1–3, 7, 8).
3. *(Done, session 26.)* **The patched images' load time (row 5):** the hooks run under the facts policy.
4. *(Done, session 27.)* **Form (t), TraitTables and TraitCSV,** with its fair baseline (pt) (rows 1, 7, 8, 11).
5. *(Done, session 27.)* **`hist`, `barplot` and `vlines!` in TraitMakie,** so that the plot matches Python's.
6. **Row 10,** a 10⁶-row file; **stock Julia** for form (t); form (t) on the system image.
7. **Form (c),** the binary, when binaries are taken up again.

**Not planned:** a precompile workload in `CSVInlineStringsExt`. It would be a workaround: it fixes form (a) for this pair of packages only, and it belongs to CSV.

**Running on the shared machine:** one Julia job at a time, niced; juliac builds alone, under the memory guard.
