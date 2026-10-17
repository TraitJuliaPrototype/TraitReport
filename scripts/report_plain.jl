# Form (a′) of TraitReport: the plain package PlainReport, its whole task precompiled.
#
#     julia --startup-file=no --project=env_p scripts/report_plain.jl <csv> <out.png>
#
# Prints the times of its marks like scripts/report_script.jl: imports, then the whole report
# (read, summary, plot and PNG run in one worker call).
T = [time()]
using PlainReport
push!(T, time())
PlainReport.report(ARGS[1], ARGS[2])
push!(T, time())
println(stderr, "T ", T[1], " ", T[2], " ", T[3])     # raw times: the harness subtracts
