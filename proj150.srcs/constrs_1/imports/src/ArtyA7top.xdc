## This file is a general .xdc for the ARTY Rev. B
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK_100MHz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK_100MHz]

# Address a warning about these 2 properies being missing: *** SEE: ug470_7Series_Config.pdf (page 29) ***
#set_property CFGBVS value1 [current_design];  #where value1 is either VCCO or GND
#set_property CONFIG_VOLTAGE value2 [current_design];  #where value2 is the voltage provided to configuration bank 0
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


##Switches

set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports {SWITCH[0]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {SWITCH[1]}]
## IGNORE upper 2 switches since PYNQ boards lack them:
#set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { SWITCH[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
#set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { SWITCH[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]

##RGB LEDs

set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports led0_b]
#set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { led0_g }]; #IO_L19N_T3_VREF_35 Sch=led0_g
#set_property -dict { PACKAGE_PIN G6    IOSTANDARD LVCMOS33 } [get_ports { led0_r }]; #IO_L19P_T3_35 Sch=led0_r
#set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS33 } [get_ports { led1_b }]; #IO_L20P_T3_35 Sch=led1_b
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports led1_g]
#set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { led1_r }]; #IO_L20N_T3_35 Sch=led1_r
## IGNORE upper 2 RGB LEDs since PYNQ board lacks them:
#set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { led2_b }]; #IO_L21N_T3_DQS_35 Sch=led2_b
#set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { led2_g }]; #IO_L22N_T3_35 Sch=led2_g
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports led2_r]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports led3_b]
#set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports { led3_g }]; #IO_L24P_T3_35 Sch=led3_g
#set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { led3_r }]; #IO_L23N_T3_35 Sch=led3_r

##LEDs

set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {LED[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {LED[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {LED[3]}]

##Buttons

set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {BUTTON[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {BUTTON[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {BUTTON[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {BUTTON[3]}]

##Pmod Header JA

## IF USING PMOD-UART, THESE ARE ALIGNED (OR PERHAPS BACKWARDS???)
#set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { CTS }]; #IO_0_15 Sch=ja[1]
#set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_TX }]; #IO_L4P_T0_15 Sch=ja[2]
#set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_RX }]; #IO_L4N_T0_15 Sch=ja[3]
#set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { RTS }]; #IO_L6P_T0_15 Sch=ja[4]
#set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { ja[4] }]; #IO_L6N_T0_VREF_15 Sch=ja[7]
#set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { ja[5] }]; #IO_L10P_T1_AD11P_15 Sch=ja[8]
#set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { ja[6] }]; #IO_L10N_T1_AD11N_15 Sch=ja[9]
#set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { ja[7] }]; #IO_25_15 Sch=ja[10]

##Pmod Header JB
### First half of PMOD-VGA (takes two full headers)
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS33} [get_ports {VGA_R[0]}]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports {VGA_R[1]}]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports {VGA_R[2]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {VGA_R[3]}]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {VGA_B[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {VGA_B[1]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {VGA_B[2]}]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {VGA_B[3]}]

##Pmod Header JC
### Second half of PMOD-VGA
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {VGA_G[0]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {VGA_G[1]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {VGA_G[2]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {VGA_G[3]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports VGA_HS_O]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports VGA_VS_O]
#set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { jc[6] }]; #IO_L23P_T3_A03_D19_14 Sch=jc_p[4]
#set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { jc[7] }]; #IO_L23N_T3_A02_D18_14 Sch=jc_n[4]

##Pmod Header JD

#set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { jd[1] }]; #IO_L11N_T1_SRCC_35 Sch=jd[1]
#set_property -dict { PACKAGE_PIN D3    IOSTANDARD LVCMOS33 } [get_ports { jd[2] }]; #IO_L12N_T1_MRCC_35 Sch=jd[2]
#set_property -dict { PACKAGE_PIN F4    IOSTANDARD LVCMOS33 } [get_ports { jd[3] }]; #IO_L13P_T2_MRCC_35 Sch=jd[3]
#set_property -dict { PACKAGE_PIN F3    IOSTANDARD LVCMOS33 } [get_ports { jd[4] }]; #IO_L13N_T2_MRCC_35 Sch=jd[4]
#set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports { jd[7] }]; #IO_L14P_T2_SRCC_35 Sch=jd[7]
#set_property -dict { PACKAGE_PIN D2    IOSTANDARD LVCMOS33 } [get_ports { jd[5] }]; #IO_L14N_T2_SRCC_35 Sch=jd[8]
#set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports { jd[6] }]; #IO_L15P_T2_DQS_35 Sch=jd[9]
#set_property -dict { PACKAGE_PIN G2    IOSTANDARD LVCMOS33 } [get_ports { jd[7] }]; #IO_L15N_T2_DQS_35 Sch=jd[10]

##USB-UART Interface
## Can use these on Arty-A7 with integrated JTAG/UART<->USB connection to PL fabric
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports FPGA_SERIAL_TX]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports FPGA_SERIAL_RX]

##ChipKit Single Ended Analog Inputs
##NOTE: The ck_an_p pins can be used as single ended analog inputs with voltages from 0-3.3V (Chipkit Analog pins A0-A5).
##      These signals should only be connected to the XADC core. When using these pins as digital I/O, use pins ck_io[14-19].

#set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[0] }]; #IO_L1N_T0_AD4N_35 Sch=ck_an_n[0]
#set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[0] }]; #IO_L1P_T0_AD4P_35 Sch=ck_an_p[0]
#set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[1] }]; #IO_L3N_T0_DQS_AD5N_35 Sch=ck_an_n[1]
#set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[1] }]; #IO_L3P_T0_DQS_AD5P_35 Sch=ck_an_p[1]
#set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[2] }]; #IO_L7N_T1_AD6N_35 Sch=ck_an_n[2]
#set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[2] }]; #IO_L7P_T1_AD6P_35 Sch=ck_an_p[2]
#set_property -dict { PACKAGE_PIN A1    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[3] }]; #IO_L9N_T1_DQS_AD7N_35 Sch=ck_an_n[3]
#set_property -dict { PACKAGE_PIN B1    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[3] }]; #IO_L9P_T1_DQS_AD7P_35 Sch=ck_an_p[3]
#set_property -dict { PACKAGE_PIN B2    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[4] }]; #IO_L10N_T1_AD15N_35 Sch=ck_an_n[4]
#set_property -dict { PACKAGE_PIN B3    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[4] }]; #IO_L10P_T1_AD15P_35 Sch=ck_an_p[4]
#set_property -dict { PACKAGE_PIN C14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[5] }]; #IO_L1N_T0_AD0N_15 Sch=ck_an_n[5]
#set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[5] }]; #IO_L1P_T0_AD0P_15 Sch=ck_an_p[5]

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L16P_T2_CSI_B_14 Sch=ck_io[0]
#set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L18P_T2_A12_D28_14 Sch=ck_io[1]
#set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L8N_T1_D12_14 Sch=ck_io[2]
#set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L19P_T3_A10_D26_14 Sch=ck_io[3]
#set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L5P_T0_D06_14 Sch=ck_io[4]
#set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
#set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L14N_T2_SRCC_14 Sch=ck_io[6]
#set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[7] }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[8] }]; #IO_L11P_T1_SRCC_14 Sch=ck_io[8]
#set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[9] }]; #IO_L10P_T1_D14_14 Sch=ck_io[9]
#set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[10] }]; #IO_L18N_T2_A11_D27_14 Sch=ck_io[10]
#set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[11] }]; #IO_L17N_T2_A13_D29_14 Sch=ck_io[11]
#set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[12] }]; #IO_L12N_T1_MRCC_14 Sch=ck_io[12]
#set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[13] }]; #IO_L12P_T1_MRCC_14 Sch=ck_io[13]

##ChipKit Digital I/O On Outer Analog Header
##NOTE: These pins should be used when using the analog header signals A0-A5 as digital I/O (Chipkit digital pins 14-19)

#set_property -dict { PACKAGE_PIN F5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[14] }]; #IO_0_35 Sch=ck_a[0]
#set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[15] }]; #IO_L4P_T0_35 Sch=ck_a[1]
#set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[16] }]; #IO_L4N_T0_35 Sch=ck_a[2]
#set_property -dict { PACKAGE_PIN E7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[17] }]; #IO_L6P_T0_35 Sch=ck_a[3]
#set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[18] }]; #IO_L6N_T0_VREF_35 Sch=ck_a[4]
#set_property -dict { PACKAGE_PIN D5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[19] }]; #IO_L11P_T1_SRCC_35 Sch=ck_a[5]

##ChipKit Digital I/O On Inner Analog Header
##NOTE: These pins will need to be connected to the XADC core when used as differential analog inputs (Chipkit analog pins A6-A11)

#set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[20] }]; #IO_L2P_T0_AD12P_35 Sch=ad_p[12]
#set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[21] }]; #IO_L2N_T0_AD12N_35 Sch=ad_n[12]
#set_property -dict { PACKAGE_PIN E6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[22] }]; #IO_L5P_T0_AD13P_35 Sch=ad_p[13]
#set_property -dict { PACKAGE_PIN E5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[23] }]; #IO_L5N_T0_AD13N_35 Sch=ad_n[13]
#set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { ck_io[24] }]; #IO_L8P_T1_AD14P_35 Sch=ad_p[14]
#set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { ck_io[25] }]; #IO_L8N_T1_AD14N_35 Sch=ad_n[14]

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_A09_D25_VREF_14 Sch=ck_io[26]
#set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L16N_T2_A15_D31_14 Sch=ck_io[27]
#set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[28] }]; #IO_L6N_T0_D08_VREF_14 Sch=ck_io[28]
#set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[29] }]; #IO_25_14 Sch=ck_io[29]
#set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[30] }]; #IO_0_14 Sch=ck_io[30]
#set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[31] }]; #IO_L5N_T0_D07_14 Sch=ck_io[31]
#set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[32] }]; #IO_L13N_T2_MRCC_14 Sch=ck_io[32]
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[33] }]; #IO_L13P_T2_MRCC_14 Sch=ck_io[33]
#set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[34] }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=ck_io[34]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[35] }]; #IO_L11N_T1_SRCC_14 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[36] }]; #IO_L8P_T1_D11_14 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[37] }]; #IO_L17P_T2_A14_D30_14 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[38] }]; #IO_L7N_T1_D10_14 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[39] }]; #IO_L7P_T1_D09_14 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[40] }]; #IO_L9N_T1_DQS_D13_14 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[41] }]; #IO_L9P_T1_DQS_14 Sch=ck_io[41]

## ChipKit SPI

#set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { ck_miso }]; #IO_L17N_T2_35 Sch=ck_miso
#set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { ck_mosi }]; #IO_L17P_T2_35 Sch=ck_mosi
#set_property -dict { PACKAGE_PIN F1    IOSTANDARD LVCMOS33 } [get_ports { ck_sck }]; #IO_L18P_T2_35 Sch=ck_sck
#set_property -dict { PACKAGE_PIN C1    IOSTANDARD LVCMOS33 } [get_ports { ck_ss }]; #IO_L16N_T2_35 Sch=ck_ss

## ChipKit I2C

#set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { ck_scl }]; #IO_L4P_T0_D04_14 Sch=ck_scl
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { ck_sda }]; #IO_L4N_T0_D05_14 Sch=ck_sda
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { scl_pup }]; #IO_L9N_T1_DQS_AD3N_15 Sch=scl_pup
#set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { sda_pup }]; #IO_L9P_T1_DQS_AD3P_15 Sch=sda_pup
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk

##Misc. ChipKit signals

#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { ck_ioa }]; #IO_L10N_T1_D15_14 Sch=ck_ioa
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports CK_RST_N]

##SMSC Ethernet PHY

#set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { eth_col }]; #IO_L16N_T2_A27_15 Sch=eth_col
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { eth_crs }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=eth_crs
#set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { eth_mdc }]; #IO_L14N_T2_SRCC_15 Sch=eth_mdc
#set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { eth_mdio }]; #IO_L17P_T2_A26_15 Sch=eth_mdio
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk
#set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { eth_rstn }]; #IO_L20P_T3_A20_15 Sch=eth_rstn
#set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_clk }]; #IO_L14P_T2_SRCC_15 Sch=eth_rx_clk
#set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_dv }]; #IO_L13N_T2_MRCC_15 Sch=eth_rx_dv
#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[0] }]; #IO_L21N_T3_DQS_A18_15 Sch=eth_rxd[0]
#set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[1] }]; #IO_L16P_T2_A28_15 Sch=eth_rxd[1]
#set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[2] }]; #IO_L21P_T3_DQS_15 Sch=eth_rxd[2]
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[3] }]; #IO_L18N_T2_A23_15 Sch=eth_rxd[3]
#set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxerr }]; #IO_L20N_T3_A19_15 Sch=eth_rxerr
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_clk }]; #IO_L13P_T2_MRCC_15 Sch=eth_tx_clk
#set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_en }]; #IO_L19N_T3_A21_VREF_15 Sch=eth_tx_en
#set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[0] }]; #IO_L15P_T2_DQS_15 Sch=eth_txd[0]
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[1] }]; #IO_L19P_T3_A22_15 Sch=eth_txd[1]
#set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[2] }]; #IO_L17N_T2_A25_15 Sch=eth_txd[2]
#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[3] }]; #IO_L18P_T2_A24_15 Sch=eth_txd[3]

##Quad SPI Flash

#set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }]; #IO_L6P_T0_FCS_B_14 Sch=qspi_cs
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[0] }]; #IO_L1P_T0_D00_MOSI_14 Sch=qspi_dq[0]
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[1] }]; #IO_L1N_T0_D01_DIN_14 Sch=qspi_dq[1]
#set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[2] }]; #IO_L2P_T0_D02_14 Sch=qspi_dq[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[3] }]; #IO_L2N_T0_D03_14 Sch=qspi_dq[3]

##Power Measurements

#set_property -dict { PACKAGE_PIN B17   IOSTANDARD LVCMOS33     } [get_ports { vsnsvu_n }]; #IO_L7N_T1_AD2N_15 Sch=ad_n[2]
#set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33     } [get_ports { vsnsvu_p }]; #IO_L7P_T1_AD2P_15 Sch=ad_p[2]
#set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33     } [get_ports { vsns5v0_n }]; #IO_L3N_T0_DQS_AD1N_15 Sch=ad_n[1]
#set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33     } [get_ports { vsns5v0_p }]; #IO_L3P_T0_DQS_AD1P_15 Sch=ad_p[1]
#set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33     } [get_ports { isns5v0_n }]; #IO_L5N_T0_AD9N_15 Sch=ad_n[9]
#set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33     } [get_ports { isns5v0_p }]; #IO_L5P_T0_AD9P_15 Sch=ad_p[9]
#set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33     } [get_ports { isns0v95_n }]; #IO_L8N_T1_AD10N_15 Sch=ad_n[10]
#set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33     } [get_ports { isns0v95_p }]; #IO_L8P_T1_AD10P_15 Sch=ad_p[10]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list top_clocks/inst/clk_cpu_50MHz]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {BUTTON_IBUF[0]} {BUTTON_IBUF[1]} {BUTTON_IBUF[2]} {BUTTON_IBUF[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {MIPS150.mem_arch/dcache/next_state__0[0]} {MIPS150.mem_arch/dcache/next_state__0[1]} {MIPS150.mem_arch/dcache/next_state__0[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 256 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {MIPS150.mem_arch/dcache/data_line_out[0]} {MIPS150.mem_arch/dcache/data_line_out[1]} {MIPS150.mem_arch/dcache/data_line_out[2]} {MIPS150.mem_arch/dcache/data_line_out[3]} {MIPS150.mem_arch/dcache/data_line_out[4]} {MIPS150.mem_arch/dcache/data_line_out[5]} {MIPS150.mem_arch/dcache/data_line_out[6]} {MIPS150.mem_arch/dcache/data_line_out[7]} {MIPS150.mem_arch/dcache/data_line_out[8]} {MIPS150.mem_arch/dcache/data_line_out[9]} {MIPS150.mem_arch/dcache/data_line_out[10]} {MIPS150.mem_arch/dcache/data_line_out[11]} {MIPS150.mem_arch/dcache/data_line_out[12]} {MIPS150.mem_arch/dcache/data_line_out[13]} {MIPS150.mem_arch/dcache/data_line_out[14]} {MIPS150.mem_arch/dcache/data_line_out[15]} {MIPS150.mem_arch/dcache/data_line_out[16]} {MIPS150.mem_arch/dcache/data_line_out[17]} {MIPS150.mem_arch/dcache/data_line_out[18]} {MIPS150.mem_arch/dcache/data_line_out[19]} {MIPS150.mem_arch/dcache/data_line_out[20]} {MIPS150.mem_arch/dcache/data_line_out[21]} {MIPS150.mem_arch/dcache/data_line_out[22]} {MIPS150.mem_arch/dcache/data_line_out[23]} {MIPS150.mem_arch/dcache/data_line_out[24]} {MIPS150.mem_arch/dcache/data_line_out[25]} {MIPS150.mem_arch/dcache/data_line_out[26]} {MIPS150.mem_arch/dcache/data_line_out[27]} {MIPS150.mem_arch/dcache/data_line_out[28]} {MIPS150.mem_arch/dcache/data_line_out[29]} {MIPS150.mem_arch/dcache/data_line_out[30]} {MIPS150.mem_arch/dcache/data_line_out[31]} {MIPS150.mem_arch/dcache/data_line_out[32]} {MIPS150.mem_arch/dcache/data_line_out[33]} {MIPS150.mem_arch/dcache/data_line_out[34]} {MIPS150.mem_arch/dcache/data_line_out[35]} {MIPS150.mem_arch/dcache/data_line_out[36]} {MIPS150.mem_arch/dcache/data_line_out[37]} {MIPS150.mem_arch/dcache/data_line_out[38]} {MIPS150.mem_arch/dcache/data_line_out[39]} {MIPS150.mem_arch/dcache/data_line_out[40]} {MIPS150.mem_arch/dcache/data_line_out[41]} {MIPS150.mem_arch/dcache/data_line_out[42]} {MIPS150.mem_arch/dcache/data_line_out[43]} {MIPS150.mem_arch/dcache/data_line_out[44]} {MIPS150.mem_arch/dcache/data_line_out[45]} {MIPS150.mem_arch/dcache/data_line_out[46]} {MIPS150.mem_arch/dcache/data_line_out[47]} {MIPS150.mem_arch/dcache/data_line_out[48]} {MIPS150.mem_arch/dcache/data_line_out[49]} {MIPS150.mem_arch/dcache/data_line_out[50]} {MIPS150.mem_arch/dcache/data_line_out[51]} {MIPS150.mem_arch/dcache/data_line_out[52]} {MIPS150.mem_arch/dcache/data_line_out[53]} {MIPS150.mem_arch/dcache/data_line_out[54]} {MIPS150.mem_arch/dcache/data_line_out[55]} {MIPS150.mem_arch/dcache/data_line_out[56]} {MIPS150.mem_arch/dcache/data_line_out[57]} {MIPS150.mem_arch/dcache/data_line_out[58]} {MIPS150.mem_arch/dcache/data_line_out[59]} {MIPS150.mem_arch/dcache/data_line_out[60]} {MIPS150.mem_arch/dcache/data_line_out[61]} {MIPS150.mem_arch/dcache/data_line_out[62]} {MIPS150.mem_arch/dcache/data_line_out[63]} {MIPS150.mem_arch/dcache/data_line_out[64]} {MIPS150.mem_arch/dcache/data_line_out[65]} {MIPS150.mem_arch/dcache/data_line_out[66]} {MIPS150.mem_arch/dcache/data_line_out[67]} {MIPS150.mem_arch/dcache/data_line_out[68]} {MIPS150.mem_arch/dcache/data_line_out[69]} {MIPS150.mem_arch/dcache/data_line_out[70]} {MIPS150.mem_arch/dcache/data_line_out[71]} {MIPS150.mem_arch/dcache/data_line_out[72]} {MIPS150.mem_arch/dcache/data_line_out[73]} {MIPS150.mem_arch/dcache/data_line_out[74]} {MIPS150.mem_arch/dcache/data_line_out[75]} {MIPS150.mem_arch/dcache/data_line_out[76]} {MIPS150.mem_arch/dcache/data_line_out[77]} {MIPS150.mem_arch/dcache/data_line_out[78]} {MIPS150.mem_arch/dcache/data_line_out[79]} {MIPS150.mem_arch/dcache/data_line_out[80]} {MIPS150.mem_arch/dcache/data_line_out[81]} {MIPS150.mem_arch/dcache/data_line_out[82]} {MIPS150.mem_arch/dcache/data_line_out[83]} {MIPS150.mem_arch/dcache/data_line_out[84]} {MIPS150.mem_arch/dcache/data_line_out[85]} {MIPS150.mem_arch/dcache/data_line_out[86]} {MIPS150.mem_arch/dcache/data_line_out[87]} {MIPS150.mem_arch/dcache/data_line_out[88]} {MIPS150.mem_arch/dcache/data_line_out[89]} {MIPS150.mem_arch/dcache/data_line_out[90]} {MIPS150.mem_arch/dcache/data_line_out[91]} {MIPS150.mem_arch/dcache/data_line_out[92]} {MIPS150.mem_arch/dcache/data_line_out[93]} {MIPS150.mem_arch/dcache/data_line_out[94]} {MIPS150.mem_arch/dcache/data_line_out[95]} {MIPS150.mem_arch/dcache/data_line_out[96]} {MIPS150.mem_arch/dcache/data_line_out[97]} {MIPS150.mem_arch/dcache/data_line_out[98]} {MIPS150.mem_arch/dcache/data_line_out[99]} {MIPS150.mem_arch/dcache/data_line_out[100]} {MIPS150.mem_arch/dcache/data_line_out[101]} {MIPS150.mem_arch/dcache/data_line_out[102]} {MIPS150.mem_arch/dcache/data_line_out[103]} {MIPS150.mem_arch/dcache/data_line_out[104]} {MIPS150.mem_arch/dcache/data_line_out[105]} {MIPS150.mem_arch/dcache/data_line_out[106]} {MIPS150.mem_arch/dcache/data_line_out[107]} {MIPS150.mem_arch/dcache/data_line_out[108]} {MIPS150.mem_arch/dcache/data_line_out[109]} {MIPS150.mem_arch/dcache/data_line_out[110]} {MIPS150.mem_arch/dcache/data_line_out[111]} {MIPS150.mem_arch/dcache/data_line_out[112]} {MIPS150.mem_arch/dcache/data_line_out[113]} {MIPS150.mem_arch/dcache/data_line_out[114]} {MIPS150.mem_arch/dcache/data_line_out[115]} {MIPS150.mem_arch/dcache/data_line_out[116]} {MIPS150.mem_arch/dcache/data_line_out[117]} {MIPS150.mem_arch/dcache/data_line_out[118]} {MIPS150.mem_arch/dcache/data_line_out[119]} {MIPS150.mem_arch/dcache/data_line_out[120]} {MIPS150.mem_arch/dcache/data_line_out[121]} {MIPS150.mem_arch/dcache/data_line_out[122]} {MIPS150.mem_arch/dcache/data_line_out[123]} {MIPS150.mem_arch/dcache/data_line_out[124]} {MIPS150.mem_arch/dcache/data_line_out[125]} {MIPS150.mem_arch/dcache/data_line_out[126]} {MIPS150.mem_arch/dcache/data_line_out[127]} {MIPS150.mem_arch/dcache/data_line_out[128]} {MIPS150.mem_arch/dcache/data_line_out[129]} {MIPS150.mem_arch/dcache/data_line_out[130]} {MIPS150.mem_arch/dcache/data_line_out[131]} {MIPS150.mem_arch/dcache/data_line_out[132]} {MIPS150.mem_arch/dcache/data_line_out[133]} {MIPS150.mem_arch/dcache/data_line_out[134]} {MIPS150.mem_arch/dcache/data_line_out[135]} {MIPS150.mem_arch/dcache/data_line_out[136]} {MIPS150.mem_arch/dcache/data_line_out[137]} {MIPS150.mem_arch/dcache/data_line_out[138]} {MIPS150.mem_arch/dcache/data_line_out[139]} {MIPS150.mem_arch/dcache/data_line_out[140]} {MIPS150.mem_arch/dcache/data_line_out[141]} {MIPS150.mem_arch/dcache/data_line_out[142]} {MIPS150.mem_arch/dcache/data_line_out[143]} {MIPS150.mem_arch/dcache/data_line_out[144]} {MIPS150.mem_arch/dcache/data_line_out[145]} {MIPS150.mem_arch/dcache/data_line_out[146]} {MIPS150.mem_arch/dcache/data_line_out[147]} {MIPS150.mem_arch/dcache/data_line_out[148]} {MIPS150.mem_arch/dcache/data_line_out[149]} {MIPS150.mem_arch/dcache/data_line_out[150]} {MIPS150.mem_arch/dcache/data_line_out[151]} {MIPS150.mem_arch/dcache/data_line_out[152]} {MIPS150.mem_arch/dcache/data_line_out[153]} {MIPS150.mem_arch/dcache/data_line_out[154]} {MIPS150.mem_arch/dcache/data_line_out[155]} {MIPS150.mem_arch/dcache/data_line_out[156]} {MIPS150.mem_arch/dcache/data_line_out[157]} {MIPS150.mem_arch/dcache/data_line_out[158]} {MIPS150.mem_arch/dcache/data_line_out[159]} {MIPS150.mem_arch/dcache/data_line_out[160]} {MIPS150.mem_arch/dcache/data_line_out[161]} {MIPS150.mem_arch/dcache/data_line_out[162]} {MIPS150.mem_arch/dcache/data_line_out[163]} {MIPS150.mem_arch/dcache/data_line_out[164]} {MIPS150.mem_arch/dcache/data_line_out[165]} {MIPS150.mem_arch/dcache/data_line_out[166]} {MIPS150.mem_arch/dcache/data_line_out[167]} {MIPS150.mem_arch/dcache/data_line_out[168]} {MIPS150.mem_arch/dcache/data_line_out[169]} {MIPS150.mem_arch/dcache/data_line_out[170]} {MIPS150.mem_arch/dcache/data_line_out[171]} {MIPS150.mem_arch/dcache/data_line_out[172]} {MIPS150.mem_arch/dcache/data_line_out[173]} {MIPS150.mem_arch/dcache/data_line_out[174]} {MIPS150.mem_arch/dcache/data_line_out[175]} {MIPS150.mem_arch/dcache/data_line_out[176]} {MIPS150.mem_arch/dcache/data_line_out[177]} {MIPS150.mem_arch/dcache/data_line_out[178]} {MIPS150.mem_arch/dcache/data_line_out[179]} {MIPS150.mem_arch/dcache/data_line_out[180]} {MIPS150.mem_arch/dcache/data_line_out[181]} {MIPS150.mem_arch/dcache/data_line_out[182]} {MIPS150.mem_arch/dcache/data_line_out[183]} {MIPS150.mem_arch/dcache/data_line_out[184]} {MIPS150.mem_arch/dcache/data_line_out[185]} {MIPS150.mem_arch/dcache/data_line_out[186]} {MIPS150.mem_arch/dcache/data_line_out[187]} {MIPS150.mem_arch/dcache/data_line_out[188]} {MIPS150.mem_arch/dcache/data_line_out[189]} {MIPS150.mem_arch/dcache/data_line_out[190]} {MIPS150.mem_arch/dcache/data_line_out[191]} {MIPS150.mem_arch/dcache/data_line_out[192]} {MIPS150.mem_arch/dcache/data_line_out[193]} {MIPS150.mem_arch/dcache/data_line_out[194]} {MIPS150.mem_arch/dcache/data_line_out[195]} {MIPS150.mem_arch/dcache/data_line_out[196]} {MIPS150.mem_arch/dcache/data_line_out[197]} {MIPS150.mem_arch/dcache/data_line_out[198]} {MIPS150.mem_arch/dcache/data_line_out[199]} {MIPS150.mem_arch/dcache/data_line_out[200]} {MIPS150.mem_arch/dcache/data_line_out[201]} {MIPS150.mem_arch/dcache/data_line_out[202]} {MIPS150.mem_arch/dcache/data_line_out[203]} {MIPS150.mem_arch/dcache/data_line_out[204]} {MIPS150.mem_arch/dcache/data_line_out[205]} {MIPS150.mem_arch/dcache/data_line_out[206]} {MIPS150.mem_arch/dcache/data_line_out[207]} {MIPS150.mem_arch/dcache/data_line_out[208]} {MIPS150.mem_arch/dcache/data_line_out[209]} {MIPS150.mem_arch/dcache/data_line_out[210]} {MIPS150.mem_arch/dcache/data_line_out[211]} {MIPS150.mem_arch/dcache/data_line_out[212]} {MIPS150.mem_arch/dcache/data_line_out[213]} {MIPS150.mem_arch/dcache/data_line_out[214]} {MIPS150.mem_arch/dcache/data_line_out[215]} {MIPS150.mem_arch/dcache/data_line_out[216]} {MIPS150.mem_arch/dcache/data_line_out[217]} {MIPS150.mem_arch/dcache/data_line_out[218]} {MIPS150.mem_arch/dcache/data_line_out[219]} {MIPS150.mem_arch/dcache/data_line_out[220]} {MIPS150.mem_arch/dcache/data_line_out[221]} {MIPS150.mem_arch/dcache/data_line_out[222]} {MIPS150.mem_arch/dcache/data_line_out[223]} {MIPS150.mem_arch/dcache/data_line_out[224]} {MIPS150.mem_arch/dcache/data_line_out[225]} {MIPS150.mem_arch/dcache/data_line_out[226]} {MIPS150.mem_arch/dcache/data_line_out[227]} {MIPS150.mem_arch/dcache/data_line_out[228]} {MIPS150.mem_arch/dcache/data_line_out[229]} {MIPS150.mem_arch/dcache/data_line_out[230]} {MIPS150.mem_arch/dcache/data_line_out[231]} {MIPS150.mem_arch/dcache/data_line_out[232]} {MIPS150.mem_arch/dcache/data_line_out[233]} {MIPS150.mem_arch/dcache/data_line_out[234]} {MIPS150.mem_arch/dcache/data_line_out[235]} {MIPS150.mem_arch/dcache/data_line_out[236]} {MIPS150.mem_arch/dcache/data_line_out[237]} {MIPS150.mem_arch/dcache/data_line_out[238]} {MIPS150.mem_arch/dcache/data_line_out[239]} {MIPS150.mem_arch/dcache/data_line_out[240]} {MIPS150.mem_arch/dcache/data_line_out[241]} {MIPS150.mem_arch/dcache/data_line_out[242]} {MIPS150.mem_arch/dcache/data_line_out[243]} {MIPS150.mem_arch/dcache/data_line_out[244]} {MIPS150.mem_arch/dcache/data_line_out[245]} {MIPS150.mem_arch/dcache/data_line_out[246]} {MIPS150.mem_arch/dcache/data_line_out[247]} {MIPS150.mem_arch/dcache/data_line_out[248]} {MIPS150.mem_arch/dcache/data_line_out[249]} {MIPS150.mem_arch/dcache/data_line_out[250]} {MIPS150.mem_arch/dcache/data_line_out[251]} {MIPS150.mem_arch/dcache/data_line_out[252]} {MIPS150.mem_arch/dcache/data_line_out[253]} {MIPS150.mem_arch/dcache/data_line_out[254]} {MIPS150.mem_arch/dcache/data_line_out[255]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 256 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {MIPS150.mem_arch/dcache/data_line_in[0]} {MIPS150.mem_arch/dcache/data_line_in[1]} {MIPS150.mem_arch/dcache/data_line_in[2]} {MIPS150.mem_arch/dcache/data_line_in[3]} {MIPS150.mem_arch/dcache/data_line_in[4]} {MIPS150.mem_arch/dcache/data_line_in[5]} {MIPS150.mem_arch/dcache/data_line_in[6]} {MIPS150.mem_arch/dcache/data_line_in[7]} {MIPS150.mem_arch/dcache/data_line_in[8]} {MIPS150.mem_arch/dcache/data_line_in[9]} {MIPS150.mem_arch/dcache/data_line_in[10]} {MIPS150.mem_arch/dcache/data_line_in[11]} {MIPS150.mem_arch/dcache/data_line_in[12]} {MIPS150.mem_arch/dcache/data_line_in[13]} {MIPS150.mem_arch/dcache/data_line_in[14]} {MIPS150.mem_arch/dcache/data_line_in[15]} {MIPS150.mem_arch/dcache/data_line_in[16]} {MIPS150.mem_arch/dcache/data_line_in[17]} {MIPS150.mem_arch/dcache/data_line_in[18]} {MIPS150.mem_arch/dcache/data_line_in[19]} {MIPS150.mem_arch/dcache/data_line_in[20]} {MIPS150.mem_arch/dcache/data_line_in[21]} {MIPS150.mem_arch/dcache/data_line_in[22]} {MIPS150.mem_arch/dcache/data_line_in[23]} {MIPS150.mem_arch/dcache/data_line_in[24]} {MIPS150.mem_arch/dcache/data_line_in[25]} {MIPS150.mem_arch/dcache/data_line_in[26]} {MIPS150.mem_arch/dcache/data_line_in[27]} {MIPS150.mem_arch/dcache/data_line_in[28]} {MIPS150.mem_arch/dcache/data_line_in[29]} {MIPS150.mem_arch/dcache/data_line_in[30]} {MIPS150.mem_arch/dcache/data_line_in[31]} {MIPS150.mem_arch/dcache/data_line_in[32]} {MIPS150.mem_arch/dcache/data_line_in[33]} {MIPS150.mem_arch/dcache/data_line_in[34]} {MIPS150.mem_arch/dcache/data_line_in[35]} {MIPS150.mem_arch/dcache/data_line_in[36]} {MIPS150.mem_arch/dcache/data_line_in[37]} {MIPS150.mem_arch/dcache/data_line_in[38]} {MIPS150.mem_arch/dcache/data_line_in[39]} {MIPS150.mem_arch/dcache/data_line_in[40]} {MIPS150.mem_arch/dcache/data_line_in[41]} {MIPS150.mem_arch/dcache/data_line_in[42]} {MIPS150.mem_arch/dcache/data_line_in[43]} {MIPS150.mem_arch/dcache/data_line_in[44]} {MIPS150.mem_arch/dcache/data_line_in[45]} {MIPS150.mem_arch/dcache/data_line_in[46]} {MIPS150.mem_arch/dcache/data_line_in[47]} {MIPS150.mem_arch/dcache/data_line_in[48]} {MIPS150.mem_arch/dcache/data_line_in[49]} {MIPS150.mem_arch/dcache/data_line_in[50]} {MIPS150.mem_arch/dcache/data_line_in[51]} {MIPS150.mem_arch/dcache/data_line_in[52]} {MIPS150.mem_arch/dcache/data_line_in[53]} {MIPS150.mem_arch/dcache/data_line_in[54]} {MIPS150.mem_arch/dcache/data_line_in[55]} {MIPS150.mem_arch/dcache/data_line_in[56]} {MIPS150.mem_arch/dcache/data_line_in[57]} {MIPS150.mem_arch/dcache/data_line_in[58]} {MIPS150.mem_arch/dcache/data_line_in[59]} {MIPS150.mem_arch/dcache/data_line_in[60]} {MIPS150.mem_arch/dcache/data_line_in[61]} {MIPS150.mem_arch/dcache/data_line_in[62]} {MIPS150.mem_arch/dcache/data_line_in[63]} {MIPS150.mem_arch/dcache/data_line_in[64]} {MIPS150.mem_arch/dcache/data_line_in[65]} {MIPS150.mem_arch/dcache/data_line_in[66]} {MIPS150.mem_arch/dcache/data_line_in[67]} {MIPS150.mem_arch/dcache/data_line_in[68]} {MIPS150.mem_arch/dcache/data_line_in[69]} {MIPS150.mem_arch/dcache/data_line_in[70]} {MIPS150.mem_arch/dcache/data_line_in[71]} {MIPS150.mem_arch/dcache/data_line_in[72]} {MIPS150.mem_arch/dcache/data_line_in[73]} {MIPS150.mem_arch/dcache/data_line_in[74]} {MIPS150.mem_arch/dcache/data_line_in[75]} {MIPS150.mem_arch/dcache/data_line_in[76]} {MIPS150.mem_arch/dcache/data_line_in[77]} {MIPS150.mem_arch/dcache/data_line_in[78]} {MIPS150.mem_arch/dcache/data_line_in[79]} {MIPS150.mem_arch/dcache/data_line_in[80]} {MIPS150.mem_arch/dcache/data_line_in[81]} {MIPS150.mem_arch/dcache/data_line_in[82]} {MIPS150.mem_arch/dcache/data_line_in[83]} {MIPS150.mem_arch/dcache/data_line_in[84]} {MIPS150.mem_arch/dcache/data_line_in[85]} {MIPS150.mem_arch/dcache/data_line_in[86]} {MIPS150.mem_arch/dcache/data_line_in[87]} {MIPS150.mem_arch/dcache/data_line_in[88]} {MIPS150.mem_arch/dcache/data_line_in[89]} {MIPS150.mem_arch/dcache/data_line_in[90]} {MIPS150.mem_arch/dcache/data_line_in[91]} {MIPS150.mem_arch/dcache/data_line_in[92]} {MIPS150.mem_arch/dcache/data_line_in[93]} {MIPS150.mem_arch/dcache/data_line_in[94]} {MIPS150.mem_arch/dcache/data_line_in[95]} {MIPS150.mem_arch/dcache/data_line_in[96]} {MIPS150.mem_arch/dcache/data_line_in[97]} {MIPS150.mem_arch/dcache/data_line_in[98]} {MIPS150.mem_arch/dcache/data_line_in[99]} {MIPS150.mem_arch/dcache/data_line_in[100]} {MIPS150.mem_arch/dcache/data_line_in[101]} {MIPS150.mem_arch/dcache/data_line_in[102]} {MIPS150.mem_arch/dcache/data_line_in[103]} {MIPS150.mem_arch/dcache/data_line_in[104]} {MIPS150.mem_arch/dcache/data_line_in[105]} {MIPS150.mem_arch/dcache/data_line_in[106]} {MIPS150.mem_arch/dcache/data_line_in[107]} {MIPS150.mem_arch/dcache/data_line_in[108]} {MIPS150.mem_arch/dcache/data_line_in[109]} {MIPS150.mem_arch/dcache/data_line_in[110]} {MIPS150.mem_arch/dcache/data_line_in[111]} {MIPS150.mem_arch/dcache/data_line_in[112]} {MIPS150.mem_arch/dcache/data_line_in[113]} {MIPS150.mem_arch/dcache/data_line_in[114]} {MIPS150.mem_arch/dcache/data_line_in[115]} {MIPS150.mem_arch/dcache/data_line_in[116]} {MIPS150.mem_arch/dcache/data_line_in[117]} {MIPS150.mem_arch/dcache/data_line_in[118]} {MIPS150.mem_arch/dcache/data_line_in[119]} {MIPS150.mem_arch/dcache/data_line_in[120]} {MIPS150.mem_arch/dcache/data_line_in[121]} {MIPS150.mem_arch/dcache/data_line_in[122]} {MIPS150.mem_arch/dcache/data_line_in[123]} {MIPS150.mem_arch/dcache/data_line_in[124]} {MIPS150.mem_arch/dcache/data_line_in[125]} {MIPS150.mem_arch/dcache/data_line_in[126]} {MIPS150.mem_arch/dcache/data_line_in[127]} {MIPS150.mem_arch/dcache/data_line_in[128]} {MIPS150.mem_arch/dcache/data_line_in[129]} {MIPS150.mem_arch/dcache/data_line_in[130]} {MIPS150.mem_arch/dcache/data_line_in[131]} {MIPS150.mem_arch/dcache/data_line_in[132]} {MIPS150.mem_arch/dcache/data_line_in[133]} {MIPS150.mem_arch/dcache/data_line_in[134]} {MIPS150.mem_arch/dcache/data_line_in[135]} {MIPS150.mem_arch/dcache/data_line_in[136]} {MIPS150.mem_arch/dcache/data_line_in[137]} {MIPS150.mem_arch/dcache/data_line_in[138]} {MIPS150.mem_arch/dcache/data_line_in[139]} {MIPS150.mem_arch/dcache/data_line_in[140]} {MIPS150.mem_arch/dcache/data_line_in[141]} {MIPS150.mem_arch/dcache/data_line_in[142]} {MIPS150.mem_arch/dcache/data_line_in[143]} {MIPS150.mem_arch/dcache/data_line_in[144]} {MIPS150.mem_arch/dcache/data_line_in[145]} {MIPS150.mem_arch/dcache/data_line_in[146]} {MIPS150.mem_arch/dcache/data_line_in[147]} {MIPS150.mem_arch/dcache/data_line_in[148]} {MIPS150.mem_arch/dcache/data_line_in[149]} {MIPS150.mem_arch/dcache/data_line_in[150]} {MIPS150.mem_arch/dcache/data_line_in[151]} {MIPS150.mem_arch/dcache/data_line_in[152]} {MIPS150.mem_arch/dcache/data_line_in[153]} {MIPS150.mem_arch/dcache/data_line_in[154]} {MIPS150.mem_arch/dcache/data_line_in[155]} {MIPS150.mem_arch/dcache/data_line_in[156]} {MIPS150.mem_arch/dcache/data_line_in[157]} {MIPS150.mem_arch/dcache/data_line_in[158]} {MIPS150.mem_arch/dcache/data_line_in[159]} {MIPS150.mem_arch/dcache/data_line_in[160]} {MIPS150.mem_arch/dcache/data_line_in[161]} {MIPS150.mem_arch/dcache/data_line_in[162]} {MIPS150.mem_arch/dcache/data_line_in[163]} {MIPS150.mem_arch/dcache/data_line_in[164]} {MIPS150.mem_arch/dcache/data_line_in[165]} {MIPS150.mem_arch/dcache/data_line_in[166]} {MIPS150.mem_arch/dcache/data_line_in[167]} {MIPS150.mem_arch/dcache/data_line_in[168]} {MIPS150.mem_arch/dcache/data_line_in[169]} {MIPS150.mem_arch/dcache/data_line_in[170]} {MIPS150.mem_arch/dcache/data_line_in[171]} {MIPS150.mem_arch/dcache/data_line_in[172]} {MIPS150.mem_arch/dcache/data_line_in[173]} {MIPS150.mem_arch/dcache/data_line_in[174]} {MIPS150.mem_arch/dcache/data_line_in[175]} {MIPS150.mem_arch/dcache/data_line_in[176]} {MIPS150.mem_arch/dcache/data_line_in[177]} {MIPS150.mem_arch/dcache/data_line_in[178]} {MIPS150.mem_arch/dcache/data_line_in[179]} {MIPS150.mem_arch/dcache/data_line_in[180]} {MIPS150.mem_arch/dcache/data_line_in[181]} {MIPS150.mem_arch/dcache/data_line_in[182]} {MIPS150.mem_arch/dcache/data_line_in[183]} {MIPS150.mem_arch/dcache/data_line_in[184]} {MIPS150.mem_arch/dcache/data_line_in[185]} {MIPS150.mem_arch/dcache/data_line_in[186]} {MIPS150.mem_arch/dcache/data_line_in[187]} {MIPS150.mem_arch/dcache/data_line_in[188]} {MIPS150.mem_arch/dcache/data_line_in[189]} {MIPS150.mem_arch/dcache/data_line_in[190]} {MIPS150.mem_arch/dcache/data_line_in[191]} {MIPS150.mem_arch/dcache/data_line_in[192]} {MIPS150.mem_arch/dcache/data_line_in[193]} {MIPS150.mem_arch/dcache/data_line_in[194]} {MIPS150.mem_arch/dcache/data_line_in[195]} {MIPS150.mem_arch/dcache/data_line_in[196]} {MIPS150.mem_arch/dcache/data_line_in[197]} {MIPS150.mem_arch/dcache/data_line_in[198]} {MIPS150.mem_arch/dcache/data_line_in[199]} {MIPS150.mem_arch/dcache/data_line_in[200]} {MIPS150.mem_arch/dcache/data_line_in[201]} {MIPS150.mem_arch/dcache/data_line_in[202]} {MIPS150.mem_arch/dcache/data_line_in[203]} {MIPS150.mem_arch/dcache/data_line_in[204]} {MIPS150.mem_arch/dcache/data_line_in[205]} {MIPS150.mem_arch/dcache/data_line_in[206]} {MIPS150.mem_arch/dcache/data_line_in[207]} {MIPS150.mem_arch/dcache/data_line_in[208]} {MIPS150.mem_arch/dcache/data_line_in[209]} {MIPS150.mem_arch/dcache/data_line_in[210]} {MIPS150.mem_arch/dcache/data_line_in[211]} {MIPS150.mem_arch/dcache/data_line_in[212]} {MIPS150.mem_arch/dcache/data_line_in[213]} {MIPS150.mem_arch/dcache/data_line_in[214]} {MIPS150.mem_arch/dcache/data_line_in[215]} {MIPS150.mem_arch/dcache/data_line_in[216]} {MIPS150.mem_arch/dcache/data_line_in[217]} {MIPS150.mem_arch/dcache/data_line_in[218]} {MIPS150.mem_arch/dcache/data_line_in[219]} {MIPS150.mem_arch/dcache/data_line_in[220]} {MIPS150.mem_arch/dcache/data_line_in[221]} {MIPS150.mem_arch/dcache/data_line_in[222]} {MIPS150.mem_arch/dcache/data_line_in[223]} {MIPS150.mem_arch/dcache/data_line_in[224]} {MIPS150.mem_arch/dcache/data_line_in[225]} {MIPS150.mem_arch/dcache/data_line_in[226]} {MIPS150.mem_arch/dcache/data_line_in[227]} {MIPS150.mem_arch/dcache/data_line_in[228]} {MIPS150.mem_arch/dcache/data_line_in[229]} {MIPS150.mem_arch/dcache/data_line_in[230]} {MIPS150.mem_arch/dcache/data_line_in[231]} {MIPS150.mem_arch/dcache/data_line_in[232]} {MIPS150.mem_arch/dcache/data_line_in[233]} {MIPS150.mem_arch/dcache/data_line_in[234]} {MIPS150.mem_arch/dcache/data_line_in[235]} {MIPS150.mem_arch/dcache/data_line_in[236]} {MIPS150.mem_arch/dcache/data_line_in[237]} {MIPS150.mem_arch/dcache/data_line_in[238]} {MIPS150.mem_arch/dcache/data_line_in[239]} {MIPS150.mem_arch/dcache/data_line_in[240]} {MIPS150.mem_arch/dcache/data_line_in[241]} {MIPS150.mem_arch/dcache/data_line_in[242]} {MIPS150.mem_arch/dcache/data_line_in[243]} {MIPS150.mem_arch/dcache/data_line_in[244]} {MIPS150.mem_arch/dcache/data_line_in[245]} {MIPS150.mem_arch/dcache/data_line_in[246]} {MIPS150.mem_arch/dcache/data_line_in[247]} {MIPS150.mem_arch/dcache/data_line_in[248]} {MIPS150.mem_arch/dcache/data_line_in[249]} {MIPS150.mem_arch/dcache/data_line_in[250]} {MIPS150.mem_arch/dcache/data_line_in[251]} {MIPS150.mem_arch/dcache/data_line_in[252]} {MIPS150.mem_arch/dcache/data_line_in[253]} {MIPS150.mem_arch/dcache/data_line_in[254]} {MIPS150.mem_arch/dcache/data_line_in[255]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 2 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {MIPS150.mem_arch/dcache/current_state[0]} {MIPS150.mem_arch/dcache/current_state[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list led0_b_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list led1_g_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list led2_r_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list led3_b_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list rst_cpu]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/sys_rst]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list clk_in_100MHz_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 1 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list locked_top_clocks]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list top_clocks/inst/locked]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list clean_rst_top/CK_RST_N_IBUF]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list top_clocks/locked]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list top_clocks/reset]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list CK_RST_N_IBUF]]
create_debug_core u_ila_2 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_2]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_2]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_2]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_2]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_2]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_2]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_2]
set_property port_width 1 [get_debug_ports u_ila_2/clk]
connect_debug_port u_ila_2/clk [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/u_mig_arty_a7_100_mig/u_ddr3_infrastructure/CLK]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
set_property port_width 16 [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[0]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[1]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[2]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[3]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[4]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[5]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[6]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[7]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[8]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[9]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[10]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[11]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[12]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[13]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[14]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_mask[15]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe1]
set_property port_width 128 [get_debug_ports u_ila_2/probe1]
connect_debug_port u_ila_2/probe1 [get_nets [list {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[0]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[1]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[2]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[3]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[4]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[5]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[6]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[7]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[8]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[9]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[10]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[11]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[12]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[13]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[14]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[15]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[16]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[17]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[18]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[19]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[20]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[21]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[22]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[23]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[24]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[25]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[26]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[27]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[28]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[29]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[30]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[31]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[32]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[33]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[34]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[35]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[36]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[37]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[38]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[39]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[40]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[41]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[42]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[43]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[44]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[45]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[46]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[47]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[48]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[49]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[50]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[51]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[52]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[53]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[54]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[55]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[56]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[57]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[58]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[59]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[60]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[61]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[62]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[63]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[64]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[65]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[66]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[67]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[68]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[69]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[70]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[71]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[72]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[73]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[74]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[75]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[76]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[77]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[78]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[79]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[80]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[81]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[82]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[83]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[84]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[85]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[86]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[87]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[88]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[89]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[90]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[91]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[92]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[93]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[94]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[95]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[96]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[97]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[98]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[99]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[100]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[101]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[102]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[103]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[104]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[105]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[106]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[107]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[108]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[109]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[110]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[111]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[112]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[113]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[114]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[115]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[116]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[117]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[118]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[119]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[120]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[121]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[122]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[123]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[124]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[125]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[126]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_data[127]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe2]
set_property port_width 2 [get_debug_ports u_ila_2/probe2]
connect_debug_port u_ila_2/probe2 [get_nets [list {MIPS150.mem_arch/u_mig_arty_a7_100/app_cmd[0]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_cmd[1]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe3]
set_property port_width 27 [get_debug_ports u_ila_2/probe3]
connect_debug_port u_ila_2/probe3 [get_nets [list {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[0]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[1]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[2]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[3]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[4]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[5]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[6]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[7]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[8]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[9]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[10]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[11]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[12]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[13]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[14]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[15]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[16]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[17]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[18]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[19]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[20]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[21]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[22]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[23]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[24]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[25]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_addr[26]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe4]
set_property port_width 128 [get_debug_ports u_ila_2/probe4]
connect_debug_port u_ila_2/probe4 [get_nets [list {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[0]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[1]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[2]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[3]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[4]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[5]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[6]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[7]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[8]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[9]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[10]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[11]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[12]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[13]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[14]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[15]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[16]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[17]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[18]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[19]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[20]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[21]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[22]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[23]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[24]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[25]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[26]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[27]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[28]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[29]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[30]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[31]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[32]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[33]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[34]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[35]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[36]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[37]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[38]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[39]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[40]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[41]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[42]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[43]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[44]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[45]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[46]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[47]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[48]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[49]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[50]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[51]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[52]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[53]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[54]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[55]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[56]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[57]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[58]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[59]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[60]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[61]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[62]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[63]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[64]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[65]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[66]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[67]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[68]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[69]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[70]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[71]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[72]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[73]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[74]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[75]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[76]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[77]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[78]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[79]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[80]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[81]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[82]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[83]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[84]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[85]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[86]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[87]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[88]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[89]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[90]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[91]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[92]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[93]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[94]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[95]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[96]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[97]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[98]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[99]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[100]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[101]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[102]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[103]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[104]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[105]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[106]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[107]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[108]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[109]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[110]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[111]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[112]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[113]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[114]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[115]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[116]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[117]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[118]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[119]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[120]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[121]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[122]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[123]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[124]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[125]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[126]} {MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data[127]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe5]
set_property port_width 1 [get_debug_ports u_ila_2/probe5]
connect_debug_port u_ila_2/probe5 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_en]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe6]
set_property port_width 1 [get_debug_ports u_ila_2/probe6]
connect_debug_port u_ila_2/probe6 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data_end]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe7]
set_property port_width 1 [get_debug_ports u_ila_2/probe7]
connect_debug_port u_ila_2/probe7 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_rd_data_valid]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe8]
set_property port_width 1 [get_debug_ports u_ila_2/probe8]
connect_debug_port u_ila_2/probe8 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_rdy]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe9]
set_property port_width 1 [get_debug_ports u_ila_2/probe9]
connect_debug_port u_ila_2/probe9 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_end]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe10]
set_property port_width 1 [get_debug_ports u_ila_2/probe10]
connect_debug_port u_ila_2/probe10 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_rdy]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe11]
set_property port_width 1 [get_debug_ports u_ila_2/probe11]
connect_debug_port u_ila_2/probe11 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/app_wdf_wren]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe12]
set_property port_width 1 [get_debug_ports u_ila_2/probe12]
connect_debug_port u_ila_2/probe12 [get_nets [list MIPS150.mem_arch/u_mig_arty_a7_100/ui_clk_sync_rst]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_2_CLK]
