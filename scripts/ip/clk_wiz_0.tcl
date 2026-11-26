# clk_wiz_0.tcl - make clk_wiz_0 the single MMCM of the design (applied after read_ip).
# 100 MHz in (No_buffer: ArtyA7top.v has its own IBUF), VCO 1000 MHz:
#   clk_cpu_50MHz /20, clk_pixel_40MHz /25, clk_migref_200MHz /5, clk_migsys_100MHz /10.
# (NUM_OUT_CLKS is derived from the CLKOUTn_USED flags.) The 4th output replaces clk_wiz_1 (101.01 MHz MIG system clock, a second MMCM).
set_property -dict [list \
    CONFIG.CLKOUT4_USED               {true} \
    CONFIG.CLK_OUT4_PORT              {clk_migsys_100MHz} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {100.000} \
] [get_ips clk_wiz_0]
