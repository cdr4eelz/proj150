# coe.tcl - read a Xilinx .coe memory image. Plain Tcl (8.5 and 8.6), no Vivado commands, so it runs under
# tclsh as well as inside vivado -mode batch. Shared by coe2mem.tcl and mmi.tcl.

# read_coe FILE -> list of the data words as integers (radix 2, 10 or 16 as declared in the file)
proc read_coe {file} {
    set fh [open $file r]
    set txt [read $fh]
    close $fh
    # ';' ends the radix/vector statements; whole-line comments start with ';' too: drop those first
    set kept {}
    foreach l [split $txt "\n"] {
        if {![regexp {^\s*;} $l]} { lappend kept $l }
    }
    set txt [join $kept "\n"]
    if {![regexp -nocase {memory_initialization_radix\s*=\s*(\d+)\s*;} $txt -> radix]} {
        error "$file: no memory_initialization_radix"
    }
    if {![regexp -nocase {memory_initialization_vector\s*=([^;]*)(;|$)} $txt -> vec]} {
        error "$file: no memory_initialization_vector"
    }
    set words {}
    foreach tok [split [string trim $vec] ", \t\r\n"] {
        if {$tok eq ""} continue
        switch -- $radix {
            16      { if {![string is xdigit -strict $tok]} { error "$file: bad hex word '$tok'" }
                      lappend words [expr {"0x$tok"}] }
            10      { if {![string is digit -strict $tok]} { error "$file: bad decimal word '$tok'" }
                      lappend words [expr {$tok + 0}] }
            2       { if {![regexp {^[01]+$} $tok]} { error "$file: bad binary word '$tok'" }
                      binary scan [binary format B* [format %064s $tok]] W v
                      lappend words $v }
            default { error "$file: unsupported radix $radix" }
        }
    }
    return $words
}
