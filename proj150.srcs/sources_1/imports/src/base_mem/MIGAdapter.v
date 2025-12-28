
module MIGAdapter (
    input  wire        ui_clk,
    input  wire        ui_rst,

    // Command/Address FIFO input (from mig_caf, 31 bits: {cmd[2:0], addr[27:0]})
    input  wire [30:0] fifo_caf_dout,
    input  wire        fifo_caf_valid,
    output wire        fifo_caf_rd_en,

    // Write Data FIFO input (from mig_wdf dout, 143:0)
    input  wire [143:0] fifo_wdf_dout,
    input  wire         fifo_wdf_valid,
    output wire         fifo_wdf_rd_en,

    // Read Data FIFO output (to mig_rdf din, 127:0 → pure 128-bit read data)
    output wire [127:0] fifo_rdf_din,
    output wire         fifo_rdf_wr_en,
    input  wire         fifo_rdf_full,   // Used for DBG, the MIG will not wait for a ready signal

    // MIG standard interface ports (UG586)
    output wire [27:0]  app_addr,
    output wire [ 2:0]  app_cmd,         // 000 = WRITE, 001 = READ
    output wire         app_en,
    input  wire         app_rdy,

    output wire [63:0]  app_wdf_data,   // Narrowed to 64-bits due to 2:1 clock ratio
    output wire [ 7:0]  app_wdf_mask,   // Only 8 bits needed for 64-bit data (8-bytes)
    output wire         app_wdf_wren,
    input  wire         app_wdf_rdy,

    input  wire [63:0]  app_rd_data,
    input  wire         app_rd_data_valid
    // NOTE: MIG read data is output when presented, no ready signal provided to hold it back!
);

    // This adapter simply maps FIFOs to MIG interface, narrowing write data to 64-bits (data is lost)
    assign app_addr = fifo_caf_dout[27:0];
    assign app_cmd = fifo_caf_dout[30:28];
    assign app_en = fifo_caf_valid;
    assign fifo_caf_rd_en = app_rdy;
    assign app_wdf_data = fifo_wdf_dout[ 63:  0]; //[127:  0];
    assign app_wdf_mask = fifo_wdf_dout[135:128]; //[143:128];
    assign app_wdf_wren = fifo_wdf_valid;
    assign fifo_wdf_rd_en = app_wdf_rdy;
    assign fifo_rdf_din = {32'hFEED_F00D, 32'hCAFE_BEEF, app_rd_data}; // TEMPORARY DUPLICATION TO FILL 128 BITS
    assign fifo_rdf_wr_en = app_rd_data_valid;
    // fifo_rdf_full is unused

endmodule
