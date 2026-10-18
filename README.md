# TraitReport

A data report: read a CSV file into a table, summarize its columns, plot a histogram to a PNG. The third demonstrator. It is the task where Julia users feel time to first plot most, measured against pandas and matplotlib doing the same. The libraries under it are TraitCSV and TraitTables (`../TraitCSV`, `../TraitTables`, trait-world reader and table), TraitMakie (`../TraitMakie`), and, in one form, the forks of CSV, DataFrames and Tables (`../forks`).

## Status (session 30, 2026-10-18)

- **Form (t) is complete for the plan's rows, as correctness.** Three datasets: the task's file (three `Float64` columns); a second shape with missing cells in four columns and a strings column (`data/sensors.csv`); a strings column read as InlineStrings' `String15` through TraitCSV's conformance in a package extension (`data/items.csv`).
- **The control is equivalent.** PlainTables prints the same summary and TraitMakie draws the same PNG as form (t), for each dataset (`scripts/check.sh`).
- **A scripted REPL session** reads, plots, changes the plot, reads the second shape, adds a column of the user's own type, reads `String15` strings and makes a plot of another type (`scripts/session.sh`, eight checks, all ok). It found one bug: displaying a table with a `String15` column raised a `TypeError` (`string` of a `String15` is a `String15`, and the printer asserts `String`). TraitTables' `cellstring` is fixed (`String(string(cell))`, TraitTables `src/TableCore.jl`) and TraitCSV has a test for it; **neither is run yet.**
- **Form (f)**, the report over the forks of CSV, DataFrames and Tables, is written (`scripts/report_forks.jl`, `env_f/`) and **has never run**: Julia runs stopped (the user's instruction, session 30) before the forks were tried. See "Form (f)".
- **Nothing was timed in session 30.** The foundation is changing (Julia parts (B), (C), then (D); TraitWorld's own policy is being removed). The numbers below are from sessions 26–27, under TraitWorld's prototype policy, and are history until re-measured ("To measure after (D)").

## The headline, by the user's criterion

The criterion: interactivity as the user perceives it. A slow import followed by instant work is fine; a warning that teaches counts as a win. So the headline is the work after the imports, not a fresh process's wall time against Python.

- **The work after `using` was instant, in every load order** (session 27, form (t)): read, summary, histogram and PNG in 66–80 ms with nine other packages loaded before or after, and none of the three libraries' compiled code lost. Imports 0.29–0.33 s. (The protection from loads is the facts mode's until the control runs the plain libraries under `--compile-by-facts=all`; review of 2026-10-18.)
- **A package extension became a conformance.** InlineStrings' `String15` joins the reader by one declaration in TraitCSV's extension; loading InlineStrings discards none of the reader's compiled code. CSV.jl's extension adds methods to CSV's internal functions instead, and its first read after DataFrames took 2.5 s against 0.19 s alone (session 26). Shown again in session 30 at the prompt.
- **A second shape of data needs nothing new.** Missing cells are two more column types (`Union{Missing, Int}`, `Union{Missing, Float64}`) that the reader tries after the plain ones; the table's code runs per column type.
- **Mistakes teach.** `floats(t, "s1")` on a column with missing cells raises "cell 2 is missing: pass skipmissing = true to leave missing cells out". A column type that conforms to nothing is refused at the bound; a conformance by a package that owns neither the trait nor the type is refused (TraitCSV's tests).
- **Not the headline:** form (t)'s fresh process, 0.52–0.56 s against Python's 0.58–0.69 s (session 27). Its fair baseline (pt), the same libraries without traits, took 0.50–0.52 s: small precompiled libraries reach Python's time with or without traits.

## The task

The task of the Python baseline, `../experiments/interfaces/python/app.py` (session 21):
- read `../experiments/interfaces/App/data/sample.csv` (200 rows, 3 `Float64` columns) into a table;
- per column: mean, sample standard deviation, min, max and sum, printed;
- a 24-bin histogram of the first numeric column, with a vertical line at its mean, titled with the file name;
- saved as a 1200 × 800 PNG.

The second and third datasets (session 30, `scripts/gendata.py`, deterministic):
- `data/sensors.csv`: 500 rows; `t`, three numeric columns with 16, 21 and 16 missing cells, a count `n` with 13, a strings column `tag`;
- `data/items.csv`: 200 rows; a strings column whose cells fit `String15`, then `x` and `n`.

## Scope: the forms in the tree

| Form | What | Files |
|---|---|---|
| (a) | an ordinary script over CSV.jl, DataFrames and TraitMakie | `scripts/report_script.jl`, `env/` |
| (a′) | the same as an ordinary package with the task in its workload: plain Julia's remedy | `PlainReport/`, `scripts/report_plain.jl`, `env_p/` |
| (b) | a small trait module calling CSV.jl and DataFrames directly | `src/ReportCore.jl`, `src/TraitReport.jl`, `scripts/report_traits.jl`, `env_b/` |
| (t) | a plain script over TraitCSV, TraitTables and TraitMakie, no workload of its own | `scripts/report_tables.jl`, `env_t/` |
| (pt) | (t)'s fair baseline: PlainTables, TraitTables and TraitCSV without traits | `PlainTables/`, `scripts/report_plaintables.jl`, `env_pt/` |
| (f) | the task over the forks of CSV, DataFrames and Tables (demonstrator 4) and TraitMakie | `scripts/report_forks.jl`, `env_f/` |
| (c) | a trimmed binary | not built |

Forms (t), (pt) and (f) take a third argument `String15`, which loads InlineStrings and makes `String15` a candidate column type. They plot the first numeric column, missing cells left out.

Other scripts: `check.sh` (forms (t) and (pt) on the three datasets), `session.jl` and `session.sh` (the REPL session), `measure.sh` (fresh-process timings), `loads.sh`, `report_loads.jl`, `invalidated.jl` and `env_loads/` (rows 7, 8), `row10.jl` and `row10.py` (a 10⁶-row file), `row11.jl` (the strings row), `gendata.py`.

**The libraries.**
- **TraitTables:** a `Column{T}` trait (`nrows`, `cell`), which every `Vector` conforms to, missing cells included; a `Table` of names and `Vector{Dynamic{Column}}` columns; selection, row selection, sorting, summaries that count missing cells, printing.
- **TraitCSV:** a `CSVColumn{T} <: Column` trait (`parsecell!`, `emptylike`) for the columns the reader can parse into: `Vector{Int}`, `Vector{Float64}`, the two with missing cells, `Vector{String}`; InlineStrings' `String15` in an extension. Per column, the reader tries the candidate column types in order, each attempt a worker compiled per column type.
- **PlainTables:** both without traits: columns as `Vector{AbstractVector}`, a function barrier per column, candidate column types as types; the same workload and the same output.

## Rows

"Shown" is correctness, session 30. "Earlier" is a measurement under TraitWorld's prototype policy (sessions 26–27; `scripts/measure.sh`, `scripts/loads.sh`, fresh processes, script mode; the full tables are in this file's git history).

| # | What | Shown (session 30) | Earlier (prototype policy) |
|---|---|---|---|
| 1 | process start to exit | — | (t) 0.52–0.56 s, (pt) 0.50–0.52 s, Python 0.58–0.69 s; (b) 1.01–1.05 s, (a′) 0.94–1.02 s, (a) 3.7–3.9 s |
| 2 | phases: imports, then the work | — | (t) imports 0.29–0.33 s, work 0.07 s; (a) read 2.6 s after DataFrames' extension invalidations |
| 3 | CSV.jl's first read, alone and with DataFrames | — | 0.19 s alone, 2.46–2.53 s with DataFrames in either order |
| 4–6 | TraitWorld's own invalidations, import and exit time | — | fixed in session 26 (type printers through Julia piece 17; hooks under the policy) |
| 7 | the work under nine loads, in either order | — | (t) 66–80 ms; (pt) 102–147 ms |
| 8 | compiled code lost to those loads | — | (t) none of TraitCSV's, TraitTables' and TraitMakie's; (pt) 17 of 49 methods |
| 9 | trimmed binary | — | not built |
| 10 | a 10⁶-row file | — | (t) 0.35 s, pandas 0.23 s (1.5×) |
| 11 | a strings column through an extension's conformance | `String15` at the prompt and in `check.sh`; (t) and (pt) agree | 0.69–0.71 s in a first session, 44 ms later (with a view cache); CSV.jl 3.9–5.0 s every session |
| 12 | a second shape: missing cells, a strings column | (t) and (pt) print the same summary and draw the same PNG | — |
| 13 | a column type of the user's own joins a read table | at the prompt (`Ramp`), summaries and sorting run | — |
| 14 | the report over the forks | form (f) written, **untested**; see "Form (f)" | — |

Whose property, after the review of 2026-10-18 (`../writeup/reviews/2026-10-18-implementation-shape.md` §5): rows 7 and 8 are the facts mode's (the compiler's) until the plain libraries run under `all`; row 11's mechanism is half traits' (a declared conformance instead of methods on internal functions) and half the facts mode's; rows 12 and 13 are traits' (a column type is a conformance; a new key compiles its own worker); row 1 shows no difference between the forms.

## Form (f): the forks

`scripts/report_forks.jl` reads with the forks' `CSV.read(path, DataFrame; stringtype)`, prints the summary in TraitTables' format (the same statistics, computed in the same order) and plots with TraitMakie, so its output can be compared with form (t)'s line by line. `env_f/` points at `../forks/{CSV,DataFrames,Tables}` by `[sources]`; the forks keep upstream's names and UUIDs.

**Untested.** Not run, not resolved (`env_f/` has no manifest). The forks' README still reports M1; their git log shows M5 in progress (`06e8b97`), so whether they load and whether `stringtype = String15` works there is open. To run, in order:
1. `julia --project=env_f -e 'using Pkg; Pkg.resolve(); Pkg.precompile()'` (offline);
2. `julia --startup-file=no --project=env_f scripts/report_forks.jl <sample.csv> f.png` and the same for `data/sensors.csv` and `data/items.csv String15`;
3. diff each output with form (t)'s (`scripts/check.sh` writes them to `$TMPDIR/traitreport_check/t_*.txt`), and compare the PNGs byte for byte. Expected: identical, since the statistics are computed by the same loops and TraitMakie draws both.

## To run before anything is measured (untested in session 30)

- `../TraitTables`: `Pkg.test()` after the `cellstring` fix (24 tests passed before the fix).
- `../TraitCSV`: `Pkg.test()`, with the new printing test (13 passed before it).
- `scripts/session.sh`: expect eight checks ok and only one `ERROR` line at the prompt, the deliberate `floats(s, "s1")` (the `TypeError` must be gone).
- `scripts/check.sh` again (it passed on all three datasets before the fix, which does not touch its paths).
- Form (f), as listed under "Form (f)".

## To measure after (D)

At the REPL (`scripts/session.jl` as the driver) and in fresh processes, patched build, no system image, view caches off:
- The work after imports for (t), (pt) and (f), on the three datasets (rows 2, 12).
- The work under the nine loads in either order, and compiled code lost, (t) under `traits` against (pt) under `all` (rows 7, 8): the control that decides whose property they are.
- The first read with `String15` in a first session, without a view cache (row 11), against CSV.jl's read alone (not with `describe` and DataFrames, review fresh-eye S4).
- A user's column type at the prompt and its first summary (row 13).
- Steady state beside first calls: each step of the session ten times.
- Row 1 last, as context, not as the headline; row 10 again.
- Form (c), the binary, with `--trim=safe`.

## What TraitWorld should provide

- **A bounded function cannot name the trait's associated type.** `summarize(c::Column, name)` would print the column's cell type `T` (`Union{Missing, Float64}`), but there is no `where {T}` for a bound. TraitTables names the type from the cells instead (the first cell's type, as `Union{Missing, …}` when cells are missing), and PlainTables does the same, so the two agree. A column of a missing-capable type without missing cells is then named by its cells' type.
- From TraitMakie (`../TraitMakie/README.md`): a generic `convert(::Type{Dynamic{X}}, x)`, forwarding for a whole family, and bound errors that list the conforming types.

## Running

- `scripts/check.sh`: forms (t) and (pt) on the three datasets.
- `scripts/session.sh`: the REPL session.
- On the shared machine: one Julia job at a time, niced, under the shared lock; `JULIA_TW_VIEWCACHE=0`.
