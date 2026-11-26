# build.tcl - non-project-mode build of proj150 (ArtyA7top) for the Arty A7-100T. Vivado 2019.1.
# Modeled on arty-mig-test/scripts/build.tcl. Does not touch proj150.xpr or its .runs/. (Tcl 8.5: no lmap)
#
#   vivado -mode batch -nojournal -source scripts/build.tcl -tclargs [clean_ip] [ip_only] [NAME=value ...]
#
#   clean_ip     delete the generated IP (proj150.srcs/sources_1/ipbuild) and recreate it
#   ip_only      create/generate/synthesize the IPs and stop
#   NAME=value   top-level parameter override, e.g. SW_STALL_EN=0 (bring-up: ignore SWITCH[1])
#
# IP: the .xci files in proj150.srcs/sources_1/ip are copied to proj150.srcs/sources_1/ipbuild/<ip>/
# (same depth, so their relative COE paths ../../imports/... still resolve), then the overrides in
# scripts/ip/*.tcl are applied. The MIG is created from scripts/ip/mig_arty_a7_100.prj (mig.tcl).
# Outputs: build/ (*.dcp, reports/, proj150_arty.bit). Fails if setup or hold slack is negative.

set ::SCRIPT_DIR [file dirname [file normalize [info script]]]
set root       [file dirname $::SCRIPT_DIR]
set part       xc7a100tcsg324-1
set top        ArtyA7top
set src1       [file join $root proj150.srcs sources_1]
set out        [file join $root build]
set rpt        [file join $out reports]
set ::IP_DIR   [file join $src1 ipbuild]
set bitfile    [file join $out proj150_arty.bit]

# IPs instantiated by the RTL (clk_wiz_1, big_mem and the old 2:1 MIG are not used any more)
set copy_ips {clk_wiz_0 bios_mem dmem_blk_mem imem_blk_mem isr_mem
              cache_data_blk_ram cache_tag_blk_ram mig_caf mig_wdf mig_rdf pixel_fifo}
set ip_overrides {clk_wiz_0.tcl mig_fifos.tcl pixel_fifo.tcl}

set ip_only 0; set clean_ip 0; set generics {}
foreach a $argv {
    if {$a eq "ip_only"} { set ip_only 1 } elseif {$a eq "clean_ip"} { set clean_ip 1 } \
    elseif {[string match *=* $a]} { lappend generics -generic $a } \
    else { error "unknown argument '$a'" }
}

file mkdir $out $rpt
puts "INFO: Vivado [version -short], part $part, generics: $generics"
create_project -in_memory -part $part
# The .xci were customized with this board selected; without it Vivado locks them (read-only CONFIG)
set_property board_part digilentinc.com:arty-a7-100:part0:1.1 [current_project]
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# ----------------------------------------------------------------------------- IP
set all_ips [concat $copy_ips mig_arty_a7_100]
set have_all [expr {!$clean_ip}]
foreach ip $all_ips { if {![file exists [file join $::IP_DIR $ip $ip.xci]]} { set have_all 0 } }
if {$have_all} {
    puts "INFO: reusing IP in $::IP_DIR (pass clean_ip to recreate)"
    foreach ip $all_ips { read_ip [file join $::IP_DIR $ip $ip.xci] }
} else {
    file delete -force $::IP_DIR
    file mkdir $::IP_DIR
    foreach ip $copy_ips {
        file mkdir [file join $::IP_DIR $ip]
        file copy [file join $src1 ip $ip $ip.xci] [file join $::IP_DIR $ip $ip.xci]
        read_ip [file join $::IP_DIR $ip $ip.xci]
    }
    foreach t $ip_overrides { puts "INFO: IP overrides: $t"; source [file join $::SCRIPT_DIR ip $t] }
    source [file join $::SCRIPT_DIR ip mig.tcl]
}
foreach ip [get_ips] {
    if {[get_property IS_LOCKED $ip]} { puts "WARNING: IP $ip is locked: [get_property LOCK_DETAILS $ip]" }
    set xci [get_property IP_FILE $ip]
    generate_target all [get_files $xci]
    if {![file exists "[file rootname $xci].dcp"]} {
        puts "INFO: synth_ip $ip (out-of-context, first time only; the MIG takes a few minutes)"
        synth_ip [get_ips $ip]
    }
}
puts "INFO: clk_wiz_0 CLKOUT4 = [get_property CONFIG.CLKOUT4_REQUESTED_OUT_FREQ [get_ips clk_wiz_0]] MHz"
puts "INFO: pixel_fifo prog_full = [get_property CONFIG.Full_Threshold_Assert_Value [get_ips pixel_fifo]], prog_empty = [get_property CONFIG.Empty_Threshold_Assert_Value [get_ips pixel_fifo]]"
puts "INFO: mig_rdf prog_full = [get_property CONFIG.Full_Threshold_Assert_Value [get_ips mig_rdf]]"
if {$ip_only} { puts "INFO: ip_only done"; return }

# ----------------------------------------------------------------------------- synth
source [file join $::SCRIPT_DIR sources.tcl]
set s [file join $src1 imports src]
set rtl {}
foreach f $::RTL_FILES { lappend rtl [file join $src1 $f] }
read_verilog $rtl
read_xdc [file join $root proj150.srcs constrs_1 imports src ArtyA7top.xdc]
set incdirs [list $s [file join $s innerds] [file join $s base_util] [file join $s gpu] [file join $s cpu] \
                  [file join $s base_mem] [file join $s base_io] [file join $s base_vid]]

synth_design -top $top -part $part -include_dirs $incdirs {*}$generics
write_checkpoint -force [file join $out post_synth.dcp]
report_utilization    -file [file join $rpt post_synth_util.rpt]
report_timing_summary -file [file join $rpt post_synth_timing.rpt]

# ----------------------------------------------------------------------------- impl
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out post_route.dcp]

report_timing_summary -max_paths 20 -report_unconstrained -warn_on_violation \
                       -file [file join $rpt post_route_timing.rpt]
report_utilization       -file [file join $rpt post_route_util.rpt]
report_clock_utilization -file [file join $rpt clock_util.rpt]
report_clock_interaction -file [file join $rpt clock_interaction.rpt]
report_cdc               -file [file join $rpt cdc.rpt]
report_drc               -file [file join $rpt drc.rpt]
report_methodology       -file [file join $rpt methodology.rpt]
report_route_status      -file [file join $rpt route_status.rpt]

# ----------------------------------------------------------------------------- timing gate
set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set hold_path  [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
if {$setup_path eq "" || $hold_path eq ""} { error "TIMING: no constrained paths found - clocks missing?" }
set wns [get_property SLACK $setup_path]
set whs [get_property SLACK $hold_path]
puts "INFO: WNS = $wns ns   WHS = $whs ns"
set unrouted [llength [get_nets -quiet -hier -filter {ROUTE_STATUS == UNROUTED || ROUTE_STATUS == CONFLICTS}]]
if {$unrouted > 0} { error "ROUTING: $unrouted nets unrouted or conflicting" }
if {$wns < 0 || $whs < 0} {
    error "TIMING FAILED: WNS=$wns WHS=$whs (see build/reports/post_route_timing.rpt). No bitstream written."
}

# ----------------------------------------------------------------------------- bitstream
write_bitstream -force $bitfile
puts "INFO: bitstream: $bitfile"
