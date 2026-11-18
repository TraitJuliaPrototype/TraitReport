# TraitReport

A data report: read a CSV file into a table, summarize its columns, plot a histogram to a PNG. It is the task where Julia users feel the time to the first plot most, and it is measured against Python's pandas and matplotlib doing the same (`experiments/interfaces/python/app.py`). The repository holds the report in several forms, each over a different stack of libraries, with plain twins as controls.

## The forms

| Form | What | Files |
|---|---|---|
| (a) | an ordinary script over CSV.jl, DataFrames and TraitMakie | `scripts/report_script.jl`, `env/` |
| (a′) | the same as an ordinary package with the task in its precompile workload | `PlainReport/`, `scripts/report_plain.jl`, `env_p/` |
| (b) | the package `TraitReport`: a small trait module calling CSV.jl and DataFrames | `src/ReportCore.jl`, `src/TraitReport.jl`, `scripts/report_traits.jl`, `env_b/` |
| (t) | a plain script over TraitCSV, TraitTables and TraitMakie | `scripts/report_tables.jl`, `env_t/` |
| (pt) | (t)'s twin without traits: `PlainTables` | `PlainTables/`, `scripts/report_plaintables.jl`, `env_pt/` |
| (f) | the task over the forks of CSV, DataFrames and Tables (`forks/`), with TraitMakie | `scripts/report_forks.jl`, `env_fu/` (`env_f/` has no manifest) |

- Forms (t), (pt) and (f) take a third argument `String15`, which loads InlineStrings and makes `String15` a candidate column type.
- The datasets: the task's file `experiments/interfaces/App/data/sample.csv` (200 rows, three `Float64` columns); `data/sensors.csv` (missing cells in four columns, a strings column); `data/items.csv` (a strings column whose cells fit `String15`). `scripts/gendata.py` makes the two in `data/`.

## The package and its traits

`ReportCore` (`src/ReportCore.jl`), form (b)'s trait module (`@trait_module`):
- `@trait Table`: `ncols`, `colname`, `column(t, i)::Vector{Float64}`; member `Columns`, into which a DataFrame is converted (`columns(df)`).
- `@trait Job`: the declared fields `input` and `output`; member `ReportJob`.
- `summary_text`, `histogram_png`, `run_report`. `TraitReport.report(input, output)` is the ordinary layer (`src/TraitReport.jl`).

The traits of form (t) are TraitTables' `Column` and TraitCSV's `CSVColumn` (see their READMEs).

## How it uses the design

- `Table` and `Job` erase nothing by default (no `@default_dynamic`), and no box or wrapper is made: the report's methods are compiled for `Columns` and `ReportJob`.
- Form (t) runs on TraitTables and TraitCSV, whose loops pass each column as it is: each column's code is compiled for the column's type (see their READMEs). The REPL session checks that a sorted column is a new vector, a plain member of `Column` (`scripts/session.jl`).
- `src/TraitReport.jl` ends with a precompile workload in Julia's own form, as TraitTables, TraitCSV and TraitMakie write it: `if ccall(:jl_generating_output, Cint, ()) == 1 … end`.

## Running

From the workspace root, `source env.sh` first. The package has no test suite of its own; its check is a script.

- `TraitReport/scripts/check.sh`: forms (t) and (pt) on the three datasets; each pair must print the same summary and draw the same PNG. Its default Julia is `julia-next/julia` (`JULIA` overrides it, `LOCK` names the lock file).
- `JULIA=$PWD/julia-next/julia TraitReport/scripts/session.sh`: the scripted REPL session over form (t). Its default Julia is another tree, so set `JULIA`.
- `TraitReport/scripts/measure.sh [runs] [forms]`: fresh-process timings of the forms against the Python baseline. Its defaults point at other trees: set `PATCHED` (the Julia with the design), `STOCK` (plain Julia, `julia-vanilla/julia`) and `PYENV` (the Python environment).
- `scripts/loads.sh`, `scripts/report_loads.jl`, `scripts/invalidated.jl` (`env_loads/`): the work under unrelated loads; `scripts/row10.jl`, `scripts/row10.py` (a file of 10⁶ rows), `scripts/row11.jl` (a strings column).

Each environment is precompiled by the Julia that runs it.

## Results

The current numbers, each against plain Julia or Python, are in the design repository's `writeup/design/evidence.md`. The suites' last results are in its `writeup/state.md` §3.

- **Form (f)** (the forks of CSV, DataFrames and Tables with TraitMakie: the goal's task, DataFrames + Makie) runs on the unified ports, `env_fu/`: its summary and PNG equal form (t)'s, 26.4–27.0 s against Python's 0.65 s, 25.5–26.1 s of it imports (2026-11-08, W-121's E-288; the numbers: the design's evidence §3).
- Form (t) runs on the unified ports: `env_t/` and `env_pt/` name the `-unified` siblings. Its summary and PNG are identical to the plain form's (2026-11-08, `unified` f90d152208; `experiments/implementation/stack/logs/w104-slice1-TraitReport.log`). The timing scripts (`scripts/measure.sh`, `check.sh`) default to the earlier build; set `JULIA` or `PATCHED` to `julia-unified/julia`.
- On `julia-next`: `scripts/check.sh` 3 of 3 ok (forms (t) and (pt) print the same summary and draw the same PNG on the three datasets); the REPL session 8 of 8 checks ok, with the one expected error (2026-11-18, `next` 02139b2168, TraitWorld 3e64ede; `experiments/implementation/w156/logs/after-report.log`, `after-report-session.log`).
- Form (b), the package itself, loads and writes its report on `julia-next` (2026-11-18, `next` 4bf381040c, TraitWorld 6ad7098): `env_b/` resolved to the CSV.jl and DataFrames the depot holds; `ReportCore` written as a module with `@trait_module` inside.

## The design

- The design: the design repository's `writeup/reference/` (traits, facts, compiler, lowering).
- The lessons of the ports: `writeup/intro/porting.md`.
