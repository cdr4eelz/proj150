# uarx_fifo.tcl - UART receive FIFO of base_io/UARTRVA.v (cs150-1245 ISE core_ip/extra/uarx_fifo).
# Translated from the ISE CoreGen uarx_fifo.xco (FIFO Generator 9.3): 8 bits x 16384, common clock
# built-in FIFO, first-word fall-through, valid + overflow flags, single constant prog_full at 15500,
# asynchronous reset. Lets coe_to_serial stream at full speed. Expects ::IP_NAME, ::IP_DIR.
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name $::IP_NAME -dir $::IP_DIR
set_property -dict [list \
    CONFIG.Fifo_Implementation                       {Common_Clock_Builtin_FIFO} \
    CONFIG.Performance_Options                       {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width                          {8} \
    CONFIG.Input_Depth                               {16384} \
    CONFIG.Output_Data_Width                         {8} \
    CONFIG.Output_Depth                              {16384} \
    CONFIG.Reset_Type                                {Asynchronous_Reset} \
    CONFIG.Valid_Flag                                {true} \
    CONFIG.Overflow_Flag                             {true} \
    CONFIG.Programmable_Full_Type                    {Single_Programmable_Full_Threshold_Constant} \
    CONFIG.Full_Threshold_Assert_Value               {15500} \
    CONFIG.Full_Threshold_Negate_Value               {15499} \
] [get_ips $::IP_NAME]
