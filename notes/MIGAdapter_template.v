//=============================================================================
// Module: MIGAdapter
// Purpose: Interface adapter between 128-bit transaction FIFOs (CPU domain)
//          and 64-bit MIG standard user interface (ui_clk domain).
//          ** The point is to reproduce the old behavior of the DDR2 access
//             on the original Xilinx XUP board, avoiding alteration of many
//             modules. This means that 256-bits are transferred in total,
//             for each read or write. **
//
// Features:
// - Splits one READ request into four consecutive 64-bit MIG reads,
// -   assembled into two 128-bit read responses to fifo_rdf. This matches
// -   the behavior of the OLD project DDR2 controller on XUP board.
// - Splits one WRITE request into FOUR consecutive write requests to the MIG,
// -   requiring two 128-bit writes on fifo_wdf per write request on fifo_caf
// -   (again, matching OLD project behavior).
// - Read data for fifo_rdf does not hold up the request state machine, such
// -   that read requests can be issued in rapid succession.
// - Respects back-pressure (app_rdy, app_wdf_rdy) but app_rd_data_valid will
//     not wait if "rdf_full" is asserted (data is lost in that case).
// - Ignores app_rd_data_end and app_wdf_end (obsolete in MIG).
// - Write mask correctly split from wdf FIFO [143:128]
// - Arty A7-100T DDR3 MIG configuration (2:1 ratio, ui_clk ≈ 151.515 MHz)
//
//=============================================================================

module MIGAdapter (
    input  wire         ui_clk,
    input  wire         ui_clk_sync_rst,    // active-high reset for ui_clk domain

    // Command FIFO (mig_caf) - 31 bits {cmd[2:0], addr[27:0]}
    input  wire [30:0]  fifo_caf_dout,
    input  wire         fifo_caf_valid,
    output wire         fifo_caf_rd_en,

    // Write Data FIFO (mig_wdf) - 144 bits
    // [143:128] = {mask_high[7:0], mask_low[7:0]}
    // [127:64]  = data_high[63:0]
    // [63:0]    = data_low[63:0]
    input  wire [143:0] fifo_wdf_dout,
    input  wire         fifo_wdf_valid,
    output wire         fifo_wdf_rd_en,

    // Read Data FIFO (mig_rdf) - 128-bit pure read data
    output wire [127:0] fifo_rdf_din,
    output wire         fifo_rdf_wr_en,
    input  wire         fifo_rdf_full,

    // MIG standard interface (UG586)
    output wire [27:0]  app_addr,
    output wire [2:0]   app_cmd,            // 000=WRITE, 001=READ
    output wire         app_en,
    input  wire         app_rdy,

    output wire [63:0]  app_wdf_data,
    output wire [7:0]   app_wdf_mask,
    output wire         app_wdf_wren,
    input  wire         app_wdf_rdy,

    input  wire [63:0]  app_rd_data,
    input  wire         app_rd_data_valid
    // ignore app_rd_data_end
);

// INSERT FRESH CODE HERE

endmodule
