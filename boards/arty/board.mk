# boards/arty/board.mk - Digilent Arty A7-100T (the 35T is discontinued). Included by the Makefile.
PART := xc7a100tcsg324-1
TOP  := ArtyA7top
XDC  := proj150.srcs/constrs_1/imports/src/ArtyA7top.xdc
BIT  := proj150_arty.bit

# IP cores to generate (see ip/NAME.tcl, or boards/arty/ip/NAME.tcl which wins when both exist)
IPS := clk_wiz_0 mig_arty_a7_100 \
       mig_caf mig_wdf mig_rdf pixel_fifo uarx_fifo \
       bios_mem dmem_blk_mem imem_blk_mem isr_mem cache_data_blk_ram cache_tag_blk_ram
# Files an IP's Tcl refers to (the IP is regenerated when they change)
IP_DEPS_mig_arty_a7_100 := boards/arty/ip/mig_arty_a7_100.prj

# make program: the Arty's Digilent JTAG cable ONLY. The Xilinx Platform Cable USB II
# (xilinx_tcf/Xilinx/...) that drives the XUPV5 on the same hw_server is never touched.
HW_URL    := localhost:3121
HW_SERIAL := 210319BCC332A
HW_DEVICE := xc7a100t*
