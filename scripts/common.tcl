# common.tcl - shared by the stage scripts. Arguments (from the Makefile) are NAME=value tclargs:
#   BOARD PART TOP XDC IPS BUILD [GENERICS] [IP] [TIMING_GATE] ...
# Defines ::A(NAME), ::ROOT, ::SRC1, ::BOARD_DIR, ::OUT and the helpers below. (Tcl 8.5: no lmap)
set ::SCRIPT_DIR [file dirname [file normalize [info script]]]
set ::ROOT       [file dirname $::SCRIPT_DIR]
set ::SRC1       [file join $::ROOT proj150.srcs sources_1]
array set ::A {GENERICS {} TIMING_GATE 1 IP {}}
foreach a $argv {
    if {[regexp {^([A-Za-z_0-9]+)=(.*)$} $a -> k v]} { set ::A($k) $v } else { error "unknown argument '$a'" }
}
foreach k {BOARD PART BUILD} { if {![info exists ::A($k)]} { error "missing argument $k=..." } }
set ::BOARD_DIR [file join $::ROOT boards $::A(BOARD)]
set ::OUT       [file normalize $::A(BUILD)]
set ::IP_ROOT   [file join $::OUT ip]
set ::RPT       [file join $::OUT reports]
file mkdir $::OUT $::RPT
puts "INFO: Vivado [version -short], board $::A(BOARD), part $::A(PART)"

# where the Tcl for IP <name> lives
proc ip_script {name} {
    foreach d [list [file join $::BOARD_DIR ip] [file join $::ROOT ip]] {
        if {[file exists [file join $d $name.tcl]]} { return [file join $d $name.tcl] }
    }
    error "no IP script ip/$name.tcl or boards/$::A(BOARD)/ip/$name.tcl"
}

# read the generated IP (build/<board>/ip/<name>/<name>.xci) into the current in-memory project
proc read_built_ips {} {
    foreach ip $::A(IPS) {
        set xci [file join $::IP_ROOT $ip $ip.xci]
        if {![file exists $xci]} { error "IP $ip not generated ($xci): run 'make ip'" }
        read_ip $xci
    }
    foreach ip [get_ips] {
        if {[get_property IS_LOCKED $ip]} { puts "WARNING: IP $ip is locked: [get_property LOCK_DETAILS $ip]" }
        generate_target all [get_files [get_property IP_FILE $ip]]   ;# no-op when the output products are current
    }
}

# worst setup/hold slack of the open design; returns {wns whs}
proc worst_slacks {} {
    set sp [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
    set hp [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
    if {$sp eq "" || $hp eq ""} { error "TIMING: no constrained paths found - clocks missing?" }
    return [list [get_property SLACK $sp] [get_property SLACK $hp]]
}

# error out unless the routed design is fully routed and meets setup and hold (TIMING_GATE=0 to skip)
proc timing_gate {} {
    lassign [worst_slacks] wns whs
    puts "INFO: WNS = $wns ns   WHS = $whs ns"
    set unrouted [llength [get_nets -quiet -hier -filter {ROUTE_STATUS == UNROUTED || ROUTE_STATUS == CONFLICTS}]]
    if {$unrouted > 0} { error "ROUTING: $unrouted nets unrouted or conflicting" }
    if {($wns < 0 || $whs < 0) && $::A(TIMING_GATE)} {
        error "TIMING FAILED: WNS=$wns WHS=$whs (see $::RPT/post_route_timing.rpt). Pass TIMING_GATE=0 to build anyway."
    }
}
