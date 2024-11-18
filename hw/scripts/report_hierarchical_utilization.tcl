if { $::argc != 1 } {
    puts "ERROR: Program \"$::argv0\" requires 1 argument!\n"
    puts "Usage: $::argv0 <build_dir>\n"
    exit
}

set build_dir    [lindex $::argv 0]

open_project ./${build_dir}/link/vivado/vpl/prj/prj.xpr
open_run impl_1
report_utilization -hierarchical -file ./${build_dir}/link/post_impl_utilization_hierarchical.rpt
report_utilization -file ./${build_dir}/link/post_impl_utilization.rpt
report_power -file ./${build_dir}/link/post_impl_power.rpt
