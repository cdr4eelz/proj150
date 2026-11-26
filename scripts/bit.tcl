# bit.tcl - write the bitstream from the routed checkpoint. Re-checks the timing gate first, so a
# failing impl can never be turned into a bitstream by running 'make bit' again.
#   vivado -mode batch -source scripts/bit.tcl -tclargs BOARD=arty PART=.. BUILD=.. BIT=name.bit [TIMING_GATE=0]
source [file dirname [info script]]/common.tcl
open_checkpoint [file join $::OUT impl post_route.dcp]
timing_gate
set bitfile [file join $::OUT $::A(BIT)]
write_bitstream -force $bitfile
report_drc -file [file join $::RPT bitstream_drc.rpt]
puts "INFO: bitstream: $bitfile"
