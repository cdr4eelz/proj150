// CURRENTLY INCOMPLETE: Only read path implemented so far and it doesn't do
// the double-read/write (quadruple 64-bit transfers) yet.

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



/* SEPARATE app_rd_data & app_wdf_data processing here... DO NOT CHANGE ANYTHING BELOW THIS LINE */

//=============================================================================

reg [ 27:0] cmd_addr_reg;        // captured base address
reg         isFirst;            // indicates first command in output pair
wire        adv_on_First, adv_on_Second, is_read;
// Capture address when we accept the command
always @(posedge ui_clk) begin
    if (ui_clk_sync_rst) begin
        cmd_addr_reg <= 28'd0;
        isFirst      <= 1'b1;
    end else if (adv_on_First) begin
        cmd_addr_reg <= fifo_caf_dout[27:0];
        isFirst      <= 1'b0;
    end else if (adv_on_Second) begin
        cmd_addr_reg <= 28'd0;
        isFirst      <= 1'b1;
    end else begin
        cmd_addr_reg <= cmd_addr_reg;
        isFirst      <= isFirst;
    end
end

//    INPUTs  : fifo_caf_valid, app_rdy
//    OUTPUTs : fifo_caf_rd_en, app_en

assign adv_on_First = fifo_caf_valid && fifo_caf_rd_en && app_rdy && app_en;
assign adv_on_Second = !isFirst && app_rdy && app_en;
assign fifo_caf_rd_en = isFirst && app_rdy; // Only read FIFO on first command
assign app_en = (isFirst) ? fifo_caf_valid : 1'b1;
assign is_read = fifo_caf_dout[30:28] == 3'b001;
assign app_cmd  = 3'b001;   // READ
assign app_addr = (isFirst) ? fifo_caf_dout[27:0] : cmd_addr_reg + 8; // TODO: Accurate Increment!

// Tie write-related signals to safe values (no writes yet)
assign app_wdf_wren = 1'b0;
assign app_wdf_data = 64'b0;
assign app_wdf_mask = 8'hFF;
assign fifo_wdf_rd_en = 1'b0;   // not used yet



// Read data path – minimal two-state logic
reg         rd_phase;           // 0 = expect first 64-bit word, 1 = expect second
reg [63:0]  rd_stashed;         // holds the first 64-bit word until second arrives

// Reset behavior + state / data update
always @(posedge ui_clk) begin
    if (ui_clk_sync_rst) begin
        rd_phase    <= 1'b0;            // start expecting first word
        rd_stashed  <= 64'b0;           // clear staged data
    end else begin
        if (rd_phase == 1'b0) begin
            // Waiting for first read response
            if (app_rd_data_valid) begin
                rd_stashed <= app_rd_data;
                rd_phase   <= 1'b1;     // now wait for second
            end
        end else begin
            // Waiting for second read response
            if (app_rd_data_valid) begin
                rd_phase <= 1'b0;       // back to waiting for first of next pair
                // Note: we do NOT clear rd_stashed here – next cycle will overwrite it
            end
        end
    end
end

// FIFO write interface – only when we receive the second word
assign fifo_rdf_wr_en = (rd_phase == 1'b1) && app_rd_data_valid;

// FIFO data – {second received word, first received word}
assign fifo_rdf_din = {app_rd_data, rd_stashed};

// Note: fifo_rdf_full is deliberately ignored per requirement.
// If the FIFO is full when we assert wr_en, data will be lost (MIG is not stalled).

endmodule