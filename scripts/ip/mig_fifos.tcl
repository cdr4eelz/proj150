# mig_fifos.tcl - settings for the clock-crossing FIFOs between RequestController and the MIG
# (applied after read_ip).
# mig_rdf gets a prog_full flag: MigUiAdapter only issues a MIG read while prog_full is low and
# fewer than MAX_INFLIGHT (32) beats are outstanding, so 400 + 32 (+ flag latency) < 512 entries
# and a returning beat always has room. MIG read data cannot be back-pressured.
set_property -dict [list \
    CONFIG.Programmable_Full_Type      {Single_Programmable_Full_Threshold_Constant} \
    CONFIG.Full_Threshold_Assert_Value {400} \
] [get_ips mig_rdf]
