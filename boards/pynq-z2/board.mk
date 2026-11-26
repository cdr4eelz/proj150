# boards/pynq-z2/board.mk - TUL PYNQ-Z2 (xc7z020clg400-1). PLACEHOLDER: not implemented.
#
# The Zynq side still has to be written: no PL-side DDR on this board, so memory goes through the PS
# (S_AXI_HP/ACP) behind the MemoryDDR interface, a 125 MHz clock on H16, no PL UART. To add it: fill in
# the variables below the way boards/arty/board.mk does, add boards/pynq-z2/ip/*.tcl (clock, PS7 or a
# block design script, AXI back end), a constraints file and a top module.
$(error BOARD=pynq-z2 is a placeholder; only BOARD=arty is implemented)
# PART := xc7z020clg400-1
# TOP  :=
# XDC  :=
# BIT  := proj150_pynq-z2.bit
# IPS  :=
