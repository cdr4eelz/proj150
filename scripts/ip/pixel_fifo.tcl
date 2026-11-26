# pixel_fifo.tcl - thresholds for the PixelFeeder FIFO (128-bit write x 512, 32-bit read x 2048),
# applied after read_ip.
# prog_full 448/447 (write side): PixelFeeder only issues a DDR read while prog_full is low and at
#   most 32 beats are outstanding, so 448 + 32 (+ flag latency) < 512 and no beat is ever dropped.
#   (The .xci had 500, which left 12 entries for up to 32+ in-flight beats.)
# prog_empty 1600/1601 (read side, 32-bit words): the "start level" before video is offered. It must
#   be reachable below prog_full (448*4 = 1792 words); the old 1900 never would be once throttled.
set_property -dict [list \
    CONFIG.Full_Threshold_Assert_Value  {448} \
    CONFIG.Full_Threshold_Negate_Value  {447} \
    CONFIG.Empty_Threshold_Assert_Value {1600} \
    CONFIG.Empty_Threshold_Negate_Value {1601} \
] [get_ips pixel_fifo]
