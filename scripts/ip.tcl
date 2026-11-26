# ip.tcl - create, generate and out-of-context synthesize ONE IP core: ip/NAME.tcl or
# boards/BOARD/ip/NAME.tcl -> build/BOARD/ip/NAME/NAME.xci + NAME.dcp.
#   vivado -mode batch -source scripts/ip.tcl -tclargs BOARD=arty PART=... BUILD=build/arty IP=NAME
# The IP lives in a throwaway in-memory project; the .xci under build/ is just an output.
source [file join [file dirname [info script]] common.tcl]
set ::IP_NAME $::A(IP)
set ::IP_DIR  $::IP_ROOT
file delete -force [file join $::IP_DIR $::IP_NAME]
file mkdir $::IP_DIR
create_project -in_memory -part $::A(PART)
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]
source [ip_script $::IP_NAME]
set ip [get_ips $::IP_NAME]
if {[get_property IS_LOCKED $ip]} { puts "WARNING: IP $::IP_NAME is locked: [get_property LOCK_DETAILS $ip]" }
generate_target all [get_files [get_property IP_FILE $ip]]
synth_ip $ip
set dcp [file join $::IP_DIR $::IP_NAME $::IP_NAME.dcp]
if {![file exists $dcp]} { error "IP $::IP_NAME: $dcp was not produced" }
puts "INFO: IP $::IP_NAME done"
