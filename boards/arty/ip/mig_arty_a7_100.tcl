# mig_arty_a7_100.tcl - the DDR3L MIG for the Arty A7-100T, from mig_arty_a7_100.prj (next to this file).
#
# This is the configuration proven on hardware by arty-mig-test (256 MB sequential + random
# cache-line RMW, 0 errors): MIG 7-series native UI, 4:1, 3077 ps (325 MHz DDR3), ui_clk 81.25 MHz,
# 128-bit app_wdf_data/app_rd_data, 16-bit app_wdf_mask, sys_clk_i "No Buffer" at 100 MHz and
# clk_ref_i "No Buffer" at 200 MHz (both from clk_wiz_0), sys_rst ACTIVE LOW.
# Pinout, 1.35 V DDR3L and timing come unchanged from Digilent's arty-a7-100 E.0/1.1 mig.prj.
#
# Expects ::IP_NAME, ::IP_DIR and ::BOARD_DIR (boards/arty) from scripts/ip.tcl.
create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 -module_name $::IP_NAME -dir $::IP_DIR
set mig_dir [get_property IP_DIR [get_ips $::IP_NAME]]
file copy -force [file join $::BOARD_DIR ip mig_arty_a7_100.prj] [file join $mig_dir mig_a.prj]
set_property -dict [list \
    CONFIG.XML_INPUT_FILE        {mig_a.prj} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM  {Custom} \
    CONFIG.BOARD_MIG_PARAM       {Custom} \
] [get_ips $::IP_NAME]
