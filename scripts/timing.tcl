# timing.tcl - print the timing and utilization summary of the routed design (make timing).
#   vivado -mode batch -source scripts/timing.tcl -tclargs BOARD=arty PART=.. BUILD=..
source [file dirname [info script]]/common.tcl
open_checkpoint [file join $::OUT impl post_route.dcp]
lassign [worst_slacks] wns whs
report_timing_summary -max_paths 10 -file [file join $::RPT post_route_timing.rpt]
report_utilization    -file [file join $::RPT post_route_util.rpt]
set fh [open [file join $::OUT timing.txt] w]
puts $fh "WNS $wns ns (setup)\nWHS $whs ns (hold)"
foreach l [split [report_utilization -return_string] "\n"] {
    if {[regexp {^\| (Slice LUTs|Slice Registers|Block RAM Tile|DSPs|Bonded IOB|BUFGCTRL|MMCME2_ADV) +\|} $l]} { puts $fh [string trim $l] }
}
close $fh
puts "TIMING: WNS = $wns ns, WHS = $whs ns   (details: $::RPT/post_route_timing.rpt, summary: $::OUT/timing.txt)"
