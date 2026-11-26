# mmi.tcl - write the memory map (.mmi) that updatemem needs to patch the four block RAMs of the routed
# design (bios_mem, dmem_blk_ram, imem_blk_ram, isr_mem) into an existing bitstream, 'make mmi'.
#   vivado -mode batch -source scripts/mmi.tcl -tclargs BOARD=arty PART=.. BUILD=.. BIT=name.bit [DEPTH=4096] [MMI_VERIFY=0]
#
# Reads build/<board>/impl/post_route.dcp (nothing is written to it) and writes build/<board>/<bit>.mmi, one
# Processor/AddressSpace per memory (bios, dmem, imem, isr), so 'updatemem -proc <name>' picks the memory.
# write_mem_info cannot do this: it only emits an MMI for designs with a MicroBlaze/PS7 processor.
#
# The RAMB primitives are found as the RAMB18E1/RAMB36E1 cells below the instance whose REF_NAME is the IP name.
# Which bit slice of the word each primitive holds (blk_mem_gen's ramloop[k] order) is NOT assumed: the INIT_xx
# properties of every primitive are decoded and compared with the image the IP was built from, and the MMI is
# only written if every lane matches. Reference image: the .mif blk_mem_gen wrote in build/<board>/ip/<ip>/
# (what synthesis really loaded), else the COE named in the IP's .xci. A mismatch is an error, e.g. the IP was
# regenerated after the last 'make impl' (rebuild), or the routed design comes from different software.
# MMI_VERIFY=0 skips the check and falls back to ramloop[k] = bit slice k, with a warning (not recommended).
# Tcl 8.5: no lmap.
source [file join [file dirname [file normalize [info script]]] common.tcl]
source [file join $::SCRIPT_DIR coe.tcl]

# memory name  IP / REF_NAME
set MEMS {bios bios_mem  dmem dmem_blk_ram  imem imem_blk_ram  isr isr_mem}
if {![info exists ::A(DEPTH)]}      { set ::A(DEPTH) 4096 }
if {![info exists ::A(MMI_VERIFY)]} { set ::A(MMI_VERIFY) 1 }
if {![info exists ::A(BIT)]}        { error "missing argument BIT=..." }
set mmi [file join $::OUT "[file rootname $::A(BIT)].mmi"]
set rpt [file join $::RPT mmi_verify.rpt]
file delete -force $mmi          ;# never leave an MMI from an older checkpoint behind after a failure
set dcp [file join $::OUT impl post_route.dcp]
if {![file exists $dcp]} { error "no routed checkpoint $dcp: run 'make impl'" }

set REPORT {}
proc say {msg} { puts "MMI: $msg"; lappend ::REPORT $msg }

# ---- decoding helpers -------------------------------------------------------------------------
# "256'h00AB..." -> 256-character 0/1 string (MSB first)
array set HEXBITS {0 0000 1 0001 2 0010 3 0011 4 0100 5 0101 6 0110 7 0111 8 1000 9 1001
                   a 1010 b 1011 c 1100 d 1101 e 1110 f 1111}
proc init_bits {val} {
    if {![regexp {'[hH]([0-9a-fA-F]+)$} $val -> hex]} { error "cannot parse INIT value '$val'" }
    set hex [string tolower [format %064s $hex]]
    set b ""
    foreach ch [split $hex ""] { append b $::HEXBITS($ch) }
    return $b
}
proc bits2int {s} { binary scan [binary format B8 [format %08s $s]] c v; return [expr {$v & 0xFF}] }

# the data lanes of one RAMB primitive: list of DEPTH values, each DW bits wide (INIT_xx, 256 bits each;
# entry e of a W-bit-wide port sits at bit W*e; the parity bit of a 9-bit port lives in INITP and is not data)
proc cell_values {cell dw depth} {
    set per [expr {256 / $dw}]
    set vals {}
    for {set base 0} {$base < $depth} {incr base $per} {
        set bits [init_bits [get_property [format INIT_%02X [expr {$base / $per}]] $cell]]
        for {set e 0} {$e < $per && $base + $e < $depth} {incr e} {
            set hi [expr {256 - $dw * $e}]
            lappend vals [bits2int [string range $bits [expr {$hi - $dw}] [expr {$hi - 1}]]]
        }
    }
    return $vals
}
proc parity_used {cell n} {
    for {set i 0} {$i < $n} {incr i} {
        if {[regexp {[1-9a-fA-F]} [lindex [split [get_property [format INITP_%02X $i] $cell] h] end]]} { return 1 }
    }
    return 0
}
# reference words (integers, zero padded to depth) from a blk_mem_gen .mif (one binary word per line) or a .coe
proc ref_words {file depth width} {
    if {[string tolower [file extension $file]] eq ".mif"} {
        set fh [open $file r]; set lines [split [string trim [read $fh]] "\n"]; close $fh
        set words {}
        foreach l $lines {
            set l [string trim $l]
            if {![regexp {^[01]+$} $l] || [string length $l] != $width} { error "$file: not a $width-bit binary word: '$l'" }
            binary scan [binary format B32 $l] I v
            lappend words [expr {$v & 0xFFFFFFFF}]
        }
    } else {
        set words [read_coe $file]
    }
    if {[llength $words] > $depth} { error "$file: [llength $words] words > depth $depth" }
    set pad [expr {$depth - [llength $words]}]
    for {set i 0} {$i < $pad} {incr i} { lappend words 0 }
    return $words
}
proc slice_of {words s dw} {
    set mask [expr {(1 << $dw) - 1}]
    set r {}
    foreach w $words { lappend r [expr {($w >> $s) & $mask}] }
    return $r
}
proc ndiff {a b} {
    set n 0
    foreach x $a y $b { if {$x != $y} { incr n } }
    return $n
}

# match the primitives against one reference: returns {ok slices text}; slices = list of bit offsets per cell
proc try_reference {file words cells dw total depth} {
    set nl [llength $cells]
    array unset refs                ;# slice offset -> reference slice values
    for {set s 0} {$s < $total} {incr s $dw} { set refs($s) [slice_of $words $s $dw] }
    set cand {}                   ;# per cell: list of matching slice offsets
    set txt {}
    set k 0
    foreach c $cells {
        set m {}
        for {set s 0} {$s < $total} {incr s $dw} { if {[lindex $c 3] eq $refs($s)} { lappend m $s } }
        lappend cand $m
        if {$m eq {}} {
            set conv [expr {$k * $dw}]
            lappend txt "  ramloop\[$k\] [lindex $c 1]: matches no slice of the reference ([ndiff [lindex $c 3] $refs($conv)] of $depth words differ from slice $conv)"
        }
        incr k
    }
    foreach m $cand {
        if {$m eq {}} {
            if {[llength $txt] > 3} { set txt [linsert [lrange $txt 0 2] end "  ... and [expr {[llength $txt] - 3}] more primitives"] }
            return [list 0 {} [join $txt "\n"]]
        }
    }
    # assignment: singletons first, then ambiguous cells (identical lane data) take their ramloop[k] slot
    set slices [lrepeat $nl -1]
    set used {}
    for {set pass 0} {$pass < 2} {incr pass} {
        set k 0
        foreach m $cand {
            if {[lindex $slices $k] < 0} {
                set conv [expr {$k * $dw}]
                set pick {}
                if {$pass == 0 && [llength $m] == 1} { set pick [lindex $m 0] }
                if {$pass == 1} {
                    if {[lsearch -exact $m $conv] >= 0 && [lsearch -exact $used $conv] < 0} { set pick $conv } else {
                        foreach s $m { if {[lsearch -exact $used $s] < 0} { set pick $s; break } }
                    }
                }
                if {$pick ne ""} {
                    if {[lsearch -exact $used $pick] >= 0} { return [list 0 {} "  slice $pick claimed by two primitives"] }
                    lset slices $k $pick; lappend used $pick
                }
            }
            incr k
        }
    }
    foreach s $slices { if {$s < 0} { return [list 0 {} "  no consistent slice assignment"] } }
    set amb {}
    set k 0
    foreach m $cand { if {[llength $m] > 1} { lappend amb $k }; incr k }
    return [list 1 $slices $amb]
}

# ---- open the routed design ---------------------------------------------------------------------
open_checkpoint $dcp
say "routed checkpoint: $dcp ([clock format [file mtime $dcp] -format {%Y-%m-%d %H:%M:%S}])"
set allrams [get_cells -hier -filter {REF_NAME == RAMB18E1 || REF_NAME == RAMB36E1}]
set xml {}
set nmem 0
foreach {mem ip} $MEMS {
    set parents [get_cells -quiet -hier -filter "REF_NAME == $ip"]
    if {[llength $parents] != 1} { error "MMI: expected exactly one instance of $ip, found [llength $parents]: $parents" }
    set parent [lindex $parents 0]
    set cells {}                  ;# {ramloop-index site-without-prefix type values name dw}
    set type ""; set dw ""
    foreach c $allrams {
        if {[string first "$parent/" $c] != 0} continue
        if {![regexp {ramloop\[(\d+)\]} $c -> k]} { error "MMI: $c: no ramloop\[k\] in the cell name" }
        set rt [get_property REF_NAME $c]
        if {$type ne "" && $rt ne $type} { error "MMI: $ip mixes $type and $rt" }
        set type $rt
        set site [get_property SITE $c]
        if {$site eq ""} { error "MMI: $c is not placed" }
        set w [get_property READ_WIDTH_A $c]
        foreach p {READ_WIDTH_B WRITE_WIDTH_A WRITE_WIDTH_B} {
            if {[get_property $p $c] != $w} { error "MMI: $c: $p differs from READ_WIDTH_A=$w" }
        }
        # a 9-bit port is 8 data bits + 1 parity bit (parity is never used here); 1, 2 and 4 are plain data
        if {$w == 9} { set d 8 } elseif {$w == 1 || $w == 2 || $w == 4} { set d $w } else { error "MMI: $c: port width $w not supported" }
        if {$dw ne "" && $d != $dw} { error "MMI: $ip has primitives of different widths" }
        set dw $d
        regsub {^RAMB(18|36)_} $site {} xy
        if {![string match "RAMB[string range $rt 4 5]_*" $site]} { error "MMI: $c: site $site does not fit $rt" }
        lappend cells [list $k $xy [string range $rt 0 5] {} $c $w]
    }
    if {[llength $cells] == 0} { error "MMI: no RAMB18E1/RAMB36E1 below $parent" }
    set cells [lsort -integer -index 0 $cells]
    set n [llength $cells]
    set total [expr {$n * $dw}]
    set depth $::A(DEPTH)
    # the IP's own idea of its geometry (build/<board>/ip/<ip>/<ip>.xci)
    set xci [file join $::IP_ROOT $ip $ip.xci]
    set fh [open $xci r]; set xt [read $fh]; close $fh
    regexp {PARAM_VALUE\.Write_Depth_A">(\d+)<} $xt -> ipdepth
    regexp {PARAM_VALUE\.Write_Width_A">(\d+)<} $xt -> ipwidth
    regexp {PARAM_VALUE\.Coe_File">([^<]*)<} $xt -> ipcoe
    if {$ipdepth != $depth} { error "MMI: $ip is $ipdepth words deep, not DEPTH=$depth (pass DEPTH=$ipdepth)" }
    if {$ipwidth != $total} { error "MMI: $ip is $ipwidth bits wide but its $n primitives hold $total data bits" }
    set ipcoe_abs [file normalize [file join [file dirname $xci] $ipcoe]]
    # decode every primitive
    set decoded {}
    foreach c $cells {
        set name [lindex $c 4]
        if {$dw == 8 && [parity_used $name 16]} { puts "WARNING: MMI: $name has non-zero INITP (parity bits) - not covered by the MMI" }
        lappend decoded [lreplace $c 3 3 [cell_values $name $dw $depth]]
    }
    # verify / determine the bit slices
    set slices {}
    set how ""
    if {$::A(MMI_VERIFY)} {
        set refs {}
        foreach f [list [file join $::IP_ROOT $ip $ip.mif] $ipcoe_abs] { if {[file exists $f]} { lappend refs $f } }
        if {$refs eq {}} { error "MMI: no reference image for $ip (neither the IP's .mif nor $ipcoe_abs): run 'make ip'" }
        set fails {}
        foreach f $refs {
            set words [ref_words $f $depth $total]
            lassign [try_reference $f $words $decoded $dw $total $depth] ok sl info
            if {$ok} {
                set slices $sl
                set how "verified: INIT_xx of all $n primitives == [string map [list $::ROOT/ {}] $f] over $depth words"
                if {[llength $info]} { say "WARNING $mem: lanes [join $info ,] have identical data, slice taken from the ramloop\[k\] order" }
                break
            }
            lappend fails "reference [string map [list $::ROOT/ {}] $f]:\n$info"
        }
        if {$slices eq {}} {
            error "MMI: $mem ($ip): the INIT_xx contents of the routed design do not match the image the IP was built from.\n[join $fails \n]\nThe IP was probably regenerated after the last 'make impl' (check the ip/ and impl/ timestamps; 'make bit' rebuilds), or MMI_VERIFY=0 to skip this check (unsafe)."
        }
        # does the sw/ COE still say the same thing as the image in the IP?
        if {[file exists $ipcoe_abs] && [file extension [lindex $refs 0]] eq ".mif"} {
            if {[ref_words [lindex $refs 0] $depth $total] ne [ref_words $ipcoe_abs $depth $total]} {
                say "NOTE $mem: [string map [list $::ROOT/ {}] $ipcoe_abs] now differs from the image the IP was built with"
            }
        }
    } else {
        for {set k 0} {$k < $n} {incr k} { lappend slices [expr {$k * $dw}] }
        set how "NOT VERIFIED (MMI_VERIFY=0): assumed ramloop\[k\] = bit slice k"
        puts "WARNING: MMI: $mem: $how"
    }
    # report + XML
    say "$mem ($ip, [string map [list $::ROOT/ {}] $parent]): $n x [lindex [lindex $cells 0] 2], ${dw}-bit lanes, $depth words x $total bits"
    say "  $how"
    set inorder 1
    set lines {}
    for {set i 0} {$i < $n} {incr i} {
        set c [lindex $cells $i]; set s [lindex $slices $i]
        if {$s != $i * $dw} { set inorder 0 }
        lappend lines [list $s [format "  ramloop\[%2d\] -> bits \[%2d:%2d\]  %s %s" [lindex $c 0] [expr {$s + $dw - 1}] $s [lindex $c 2] [lindex $c 1]]]
        lappend lanes [list $s [lindex $c 2] [lindex $c 1]]
    }
    foreach l [lsort -integer -index 0 $lines] { say [lindex $l 1] }
    say "  ramloop order: [expr {$inorder ? {ramloop[k] = bit slice k (blk_mem_gen order)} : {NOT in ramloop order}}]"
    set bytes [expr {$depth * $total / 8}]
    append xml "  <Processor Endianness=\"Little\" InstPath=\"$mem\">\n"
    append xml "    <AddressSpace Name=\"$mem\" Begin=\"0\" End=\"[expr {$bytes - 1}]\">\n      <BusBlock>\n"
    foreach l [lsort -integer -index 0 $lanes] {
        lassign $l s mt xy
        append xml "        <BitLane MemType=\"$mt\" Placement=\"$xy\">\n"
        append xml "          <DataWidth MSB=\"[expr {$s + $dw - 1}]\" LSB=\"$s\"/>\n"
        append xml "          <AddressRange Begin=\"0\" End=\"[expr {$depth - 1}]\"/>\n"
        append xml "          <Parity ON=\"false\" NumBits=\"0\"/>\n        </BitLane>\n"
    }
    append xml "      </BusBlock>\n    </AddressSpace>\n  </Processor>\n"
    unset lanes
    incr nmem
}

set fh [open $mmi w]
puts $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
puts $fh "<!-- Written by scripts/mmi.tcl from [file tail $dcp] for updatemem (UG1580); one Processor per memory: -proc bios|dmem|imem|isr. -->"
puts $fh "<!-- Valid only for bitstreams written from this exact routed checkpoint (the placement is recorded here). -->"
puts $fh "<MemInfo Version=\"1\" Minor=\"0\">\n$xml  <Config>\n    <Option Name=\"Part\" Val=\"$::A(PART)\"/>\n  </Config>\n</MemInfo>"
close $fh
set fh [open $rpt w]
puts $fh [join $REPORT "\n"]
close $fh
puts "MMI: wrote $mmi ($nmem memories; report: $rpt)"
