# impl.tcl - opt/place/phys_opt/route the synthesized design -> build/BOARD/impl/post_route.dcp + reports.
#   vivado -mode batch -source scripts/impl.tcl -tclargs BOARD=arty PART=.. BUILD=.. [TIMING_GATE=0]
# Fails (after writing the checkpoint and reports) when the design has unrouted nets or negative slack.
source [file dirname [info script]]/common.tcl
set dir [file join $::OUT impl]
file mkdir $dir
open_checkpoint [file join $::OUT synth post_synth.dcp]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $dir post_route.dcp]
report_timing_summary -max_paths 20 -report_unconstrained -warn_on_violation -file [file join $::RPT post_route_timing.rpt]
report_utilization       -file [file join $::RPT post_route_util.rpt]
report_clock_utilization -file [file join $::RPT clock_util.rpt]
report_clock_interaction -file [file join $::RPT clock_interaction.rpt]
report_cdc               -file [file join $::RPT cdc.rpt]
report_drc               -file [file join $::RPT drc.rpt]
report_methodology       -file [file join $::RPT methodology.rpt]
report_route_status      -file [file join $::RPT route_status.rpt]
timing_gate
