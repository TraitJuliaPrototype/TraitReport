# Form (b) of TraitReport: the report's work in the trait module ReportCore (src/ReportCore.jl).
#
#     julia --startup-file=no --project=env_b scripts/report_traits.jl <csv> <out.png>
#
# Prints the times of its marks like scripts/report_script.jl: imports, then the whole report
# (read, summary, plot and PNG run in one worker call).
T = [time()]
using TraitReport
push!(T, time())
TraitReport.report(ARGS[1], ARGS[2])
push!(T, time())
println(stderr, "T ", T[1], " ", T[2], " ", T[3])     # raw times: the harness subtracts
