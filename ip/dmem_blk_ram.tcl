# dmem_blk_ram.tcl - X5 scratchpad (0x5000_0000), cs150-1245 ISE core_ip/brams/dmem_blk_ram: 32 x 4096 true
# dual-port RAM with byte writes (port A data r/w, port B instruction fetch), initialised from sw/bench.inst.coe.
# (Was proj150's single-port dmem_blk_mem.) Expects ::IP_NAME, ::IP_DIR, ::ROOT.
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $::IP_NAME -dir $::IP_DIR
set_property -dict [list \
    CONFIG.Algorithm                                 {Fixed_Primitives} \
    CONFIG.Assume_Synchronous_Clk                    {true} \
    CONFIG.Byte_Size                                 {8} \
    CONFIG.Coe_File                                  "$::ROOT/sw/bench.inst.coe" \
    CONFIG.Enable_B                                  {Use_ENB_Pin} \
    CONFIG.Fill_Remaining_Memory_Locations           {true} \
    CONFIG.Load_Init_File                            {true} \
    CONFIG.Memory_Type                               {True_Dual_Port_RAM} \
    CONFIG.Port_B_Clock                              {100} \
    CONFIG.Port_B_Enable_Rate                        {100} \
    CONFIG.Port_B_Write_Rate                         {50} \
    CONFIG.Primitive                                 {2kx9} \
    CONFIG.Read_Width_A                              {32} \
    CONFIG.Read_Width_B                              {32} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Use_Byte_Write_Enable                     {true} \
    CONFIG.Write_Depth_A                             {4096} \
    CONFIG.Write_Width_A                             {32} \
    CONFIG.Write_Width_B                             {32} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
] [get_ips $::IP_NAME]
