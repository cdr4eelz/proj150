# synth.tcl - synthesize the top module into build/BOARD/synth/post_synth.dcp (non-project mode).
#   vivado -mode batch -source scripts/synth.tcl -tclargs BOARD=arty PART=.. TOP=.. XDC=.. IPS="a b" BUILD=.. [GENERICS="N=v M=w"]
source [file dirname [info script]]/common.tcl
set dir [file join $::OUT synth]
file mkdir $dir
create_project -in_memory -part $::A(PART)
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]
read_built_ips

source [file join $::SCRIPT_DIR sources.tcl]
set rtl {}
foreach f $::RTL_FILES { lappend rtl [file join $::SRC1 $f] }
read_verilog $rtl
read_xdc [file join $::ROOT $::A(XDC)]
set s [file join $::SRC1 imports src]
set incdirs [list $s]
foreach d {innerds base_util gpu cpu base_mem base_io base_vid} { lappend incdirs [file join $s $d] }
set generics {}
foreach g $::A(GENERICS) { lappend generics -generic $g }
puts "INFO: synth_design -top $::A(TOP) generics: $generics"
synth_design -top $::A(TOP) -part $::A(PART) -include_dirs $incdirs {*}$generics
write_checkpoint -force [file join $dir post_synth.dcp]
report_utilization    -file [file join $::RPT post_synth_util.rpt]
report_timing_summary -file [file join $::RPT post_synth_timing.rpt]
