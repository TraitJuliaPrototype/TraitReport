"""
    TraitReport

The third demonstrator: a data report in a fresh session. `report(input, output)` reads a CSV
file into a DataFrame, prints a summary of its columns and plots a histogram of the first
column into a PNG. The work runs in `ReportCore`, a trait module (form (b) of README.md).
"""
module TraitReport
using TraitWorld

include("ReportCore.jl")
using .ReportCore
export report

"Read `input` (CSV), print its columns' summary to `io`, plot the first column's histogram into `output` (PNG)."
function report(input::AbstractString, output::AbstractString; io::IO = stdout)
    print(io, ReportCore.run_report(ReportJob(String(input), String(output))))
    return output
end

# a precompile workload: the whole report, on a small file like the demonstration's
TraitWorld.@workload begin
    dir = mktempdir()
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
