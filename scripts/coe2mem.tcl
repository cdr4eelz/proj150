# coe2mem.tcl - convert a Xilinx .coe image to the .mem format that updatemem reads: '@0000', then one
# hex word per line. Pads with zero words up to DEPTH (what the IP does: Fill_Remaining_Memory_Locations),
# so the patched RAM ends up exactly like a rebuilt one; fails if the image is deeper than DEPTH.
#   tclsh scripts/coe2mem.tcl IN.coe OUT.mem [DEPTH=4096] [WIDTH=32] [PAD=1]
#   vivado -mode batch -source scripts/coe2mem.tcl -tclargs IN.coe OUT.mem [DEPTH=4096] ...
# ('make patch' runs this; see the 'make mmi' / 'make patch' notes in the Makefile.)
source [file join [file dirname [file normalize [info script]]] coe.tcl]

proc die {msg} { puts stderr "coe2mem: $msg"; exit 1 }

array set opt {DEPTH 4096 WIDTH 32 PAD 1}
set pos {}
foreach a $argv {
    if {[regexp {^(DEPTH|WIDTH|PAD)=(\d+)$} $a -> k v]} { set opt($k) $v } else { lappend pos $a }
}
if {[llength $pos] != 2} { die "usage: coe2mem.tcl IN.coe OUT.mem \[DEPTH=4096\] \[WIDTH=32\] \[PAD=1\]" }
lassign $pos in out
if {$opt(WIDTH) % 4} { die "WIDTH=$opt(WIDTH) is not a multiple of 4" }

if {[catch {read_coe $in} words]} { die $words }
set n [llength $words]
if {$n > $opt(DEPTH)} {
    die "$in has $n words, deeper than the RAM ($opt(DEPTH) words): patching cannot grow it, do a full rebuild (make bit)"
}
set digits [expr {$opt(WIDTH) / 4}]
set limit  [expr {1 << $opt(WIDTH)}]
set fh [open $out w]
puts $fh "@0000"
foreach w $words {
    if {$w < 0 || $w >= $limit} { close $fh; file delete $out; die "$in: word [format %x $w] does not fit in $opt(WIDTH) bits" }
    puts $fh [format %0${digits}x $w]
}
set pad 0
if {$opt(PAD)} {
    set zero [format %0${digits}x 0]
    for {set i $n} {$i < $opt(DEPTH)} {incr i} { puts $fh $zero; incr pad }
}
close $fh
puts "coe2mem: $in -> $out: $n words + $pad zero padding = [expr {$n + $pad}] of $opt(DEPTH) ($opt(WIDTH)-bit)"
