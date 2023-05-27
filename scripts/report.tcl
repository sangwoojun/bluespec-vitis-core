set outputdir ./reports
file mkdir $outputdir
open_checkpoint ./_x/link/vivado/vpl/prj/prj.runs/impl_1/level0_wrapper_routed.dcp

report_timing_summary -file $outputdir/timing_summary.rpt
report_utilization -file $outputdir/utilization.rpt
report_utilization -hierarchical  -file $outputdir/utilization_hier.rpt
exit
