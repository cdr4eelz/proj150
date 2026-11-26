# program.tcl - load proj150_arty.bit into the Arty A7-100T over its on-board Digilent USB-JTAG
# (Copied from arty-mig-test/scripts/program.tcl.)
# (volatile: lost at power-off). Works with Vivado 2019.1 (open_hw) and newer (open_hw_manager).
#
#   vivado -mode batch -nojournal -source scripts/program.tcl -tclargs [bit] [serial] [hw_server_url]
#
#   bit      default build/proj150_arty.bit
#   serial   Digilent cable serial, e.g. 210319BCC332A (the Arty on UBU24). Optional, but required
#            if more than one Digilent cable is connected.
#   url      default localhost:3121
#
# Only Digilent targets are ever considered. Other cables on the same hw_server (for example the
# Xilinx Platform Cable USB II driving the XUPV5, target */xilinx_tcf/Xilinx/...) are ignored.
set script_dir [file dirname [file normalize [info script]]]
set bit    [file join [file dirname $script_dir] build proj150_arty.bit]
set serial ""
set url    localhost:3121
if {[llength $argv] >= 1 && [lindex $argv 0] ne ""} { set bit [file normalize [lindex $argv 0]] }
if {[llength $argv] >= 2} { set serial [lindex $argv 1] }
if {[llength $argv] >= 3} { set url    [lindex $argv 2] }
if {![file exists $bit]} { error "bitstream not found: $bit (run scripts/build.tcl first)" }

if {[catch {open_hw_manager}]} { open_hw }
connect_hw_server -url $url
puts "INFO: JTAG targets on $url:"
foreach t [get_hw_targets -quiet] { puts "INFO:   $t" }

if {$serial ne ""} {
    set targets [get_hw_targets -quiet "*/xilinx_tcf/Digilent/${serial}*"]
} else {
    set targets [get_hw_targets -quiet "*/xilinx_tcf/Digilent/*"]
}
if {[llength $targets] == 0} {
    error "no Digilent JTAG target[expr {$serial ne "" ? " with serial $serial" : ""}] - is the Arty plugged in (data cable) and are the cable drivers installed?"
}
if {[llength $targets] > 1} {
    error "several Digilent targets found ($targets); pass the Arty's serial as the 2nd -tclarg "
}
set target [lindex $targets 0]
puts "INFO: using target $target"
current_hw_target $target
open_hw_target

set devs [get_hw_devices -quiet xc7a100t*]
if {[llength $devs] != 1} { error "expected one xc7a100t on $target, found: [get_hw_devices]" }
set dev [lindex $devs 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROBES.FILE      {} $dev
set_property FULL_PROBES.FILE {} $dev
set_property PROGRAM.FILE   $bit $dev
program_hw_devices $dev
refresh_hw_device $dev
puts "INFO: programmed $dev on $target with $bit"
close_hw_target
disconnect_hw_server
if {[catch {close_hw_manager}]} { catch {close_hw} }
