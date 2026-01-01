//-----------------------------------------------------------------------------
// **** AI Generated with GROK ****
//   (Used "veo" files for FIFOs & MIG plus description and several corrections)
//
// Module: MIGAdapter
// Purpose: Adapt 128-bit wide read/write requests from CPU domain to the
//          64-bit MIG standard user interface on Arty A7-100T.
//
// Key updates from previous version:
// - app_rd_data_end is unused in this MIG configuration → ignore it completely.
//   Data is valid whenever app_rd_data_valid is asserted (single cycle per burst).
// - app_wdf_end is unused → tie to 0 (not required for correct operation).
//
// MIG configuration notes (per project specs):
// - Standard interface (UG586), 64-bit data bus
// - Clock ratio 2:1, memory clock period 3300 ps → memory clock ≈ 303.03 MHz
// - ui_clk ≈ 151.515 MHz (memory clock / 2)
// - Input clock either 100 MHz board clock or generate exact ~101.01 MHz
//
// This module operates entirely in the ui_clk domain after FIFO crossing.
// Translates one 128-bit transaction ↔ two consecutive 64-bit MIG bursts.
//
//-----------------------------------------------------------------------------

module MIGAdapter (
    input  wire        ui_clk,
    input  wire        ui_rst,

    // Command/Address FIFO input (from mig_caf, 31 bits: {cmd[2:0], addr[27:0]})
    input  wire [30:0] caf_fifo_dout,
    input  wire        caf_fifo_empty,
    output wire        caf_fifo_rd_en,

    // Write Data FIFO input (from mig_wdf dout, 143:0)
    input  wire [143:0] wdf_fifo_dout,
    input  wire         wdf_fifo_empty,
    output wire         wdf_fifo_rd_en,

    // Read Data FIFO output (to mig_rdf din, 127:0 → pure 128-bit read data)
    output wire [127:0] rdf_fifo_din,
    output wire         rdf_fifo_wr_en,
    input  wire         rdf_fifo_full,

    // MIG standard interface ports (UG586)
    output wire [27:0]  app_addr,
    output wire [2:0]   app_cmd,         // 000 = WRITE, 001 = READ
    output wire         app_en,
    input  wire         app_rdy,

    output wire [63:0]  app_wdf_data,
    output wire [7:0]   app_wdf_mask,
    output wire         app_wdf_end,     // unused in this config → tied low
    output wire         app_wdf_wren,
    input  wire         app_wdf_rdy,

    input  wire [63:0]  app_rd_data,
    // app_rd_data_end unused → not used in logic
    input  wire         app_rd_data_valid
);

    // ------------------------------------------------------------------------
    // State machine
    // ------------------------------------------------------------------------
    localparam IDLE           = 3'd0;
    localparam ISSUE_FIRST    = 3'd1;
    localparam ISSUE_SECOND   = 3'd2;
    localparam WAIT_RD_FIRST  = 3'd3;
    localparam WAIT_RD_SECOND = 3'd4;
    localparam WRITE_RDF      = 3'd5;

    reg [2:0] state, next_state;

    // Transaction registers
    reg [27:0] base_addr_reg;     // 16-byte aligned base address
    reg        is_write_reg;
    reg [63:0] wdata_low;
    reg [63:0] wdata_high;
    reg [7:0]  wmask_low;
    reg [7:0]  wmask_high;

    // Read data capture
    reg [63:0] rd_low;
    reg [63:0] rd_high;

    // ------------------------------------------------------------------------
    // FIFO read enables
    // ------------------------------------------------------------------------
    assign caf_fifo_rd_en = (state == IDLE && !caf_fifo_empty && app_rdy &&
                             (caf_fifo_dout[30:28] != 3'b000 || !wdf_fifo_empty));

    assign wdf_fifo_rd_en = (state == IDLE && !caf_fifo_empty && 
                             caf_fifo_dout[30:28] == 3'b000 && !wdf_fifo_empty && app_rdy);

    // ------------------------------------------------------------------------
    // MIG command interface
    // ------------------------------------------------------------------------
    assign app_en   = (state == ISSUE_FIRST || state == ISSUE_SECOND) && app_rdy;
    assign app_cmd  = is_write_reg ? 3'b000 : 3'b001;
    assign app_addr = (state == ISSUE_FIRST)  ? {base_addr_reg[27:1], 1'b0} :
                                               {base_addr_reg[27:1], 1'b1};  // +8 bytes

    // ------------------------------------------------------------------------
    // MIG write data interface
    // ------------------------------------------------------------------------
    assign app_wdf_wren = (state == ISSUE_FIRST || state == ISSUE_SECOND) && app_wdf_rdy;
    assign app_wdf_end  = 1'b0;  // unused in this MIG configuration → tied low
    assign app_wdf_data = (state == ISSUE_FIRST) ? wdata_low : wdata_high;
    assign app_wdf_mask = (state == ISSUE_FIRST) ? wmask_low : wmask_high;

    // ------------------------------------------------------------------------
    // Read data FIFO interface
    // ------------------------------------------------------------------------
    assign rdf_fifo_din   = {rd_high, rd_low};
    assign rdf_fifo_wr_en = (state == WRITE_RDF) && !rdf_fifo_full;

    // ------------------------------------------------------------------------
    // State machine sequential
    // ------------------------------------------------------------------------
    always @(posedge ui_clk) begin
        if (ui_rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------------------
    // State machine combinational
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!caf_fifo_empty && app_rdy &&
                    (caf_fifo_dout[30:28] != 3'b000 || !wdf_fifo_empty))
                    next_state = ISSUE_FIRST;
            end
            ISSUE_FIRST: begin
                if (app_rdy && (!is_write_reg || app_wdf_rdy))
                    next_state = ISSUE_SECOND;
            end
            ISSUE_SECOND: begin
                if (app_rdy && (!is_write_reg || app_wdf_rdy)) begin
                    if (is_write_reg)
                        next_state = IDLE;
                    else
                        next_state = WAIT_RD_FIRST;
                end
            end
            WAIT_RD_FIRST: begin
                if (app_rd_data_valid)               // ignore app_rd_data_end
                    next_state = WAIT_RD_SECOND;
            end
            WAIT_RD_SECOND: begin
                if (app_rd_data_valid)               // ignore app_rd_data_end
                    next_state = WRITE_RDF;
            end
            WRITE_RDF: begin
                if (!rdf_fifo_full)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Capture command, write data/mask, and read data
    // ------------------------------------------------------------------------
    always @(posedge ui_clk) begin
        if (ui_rst) begin
            base_addr_reg <= 28'd0;
            is_write_reg  <= 1'b0;
            wdata_low     <= 64'd0;
            wdata_high    <= 64'd0;
            wmask_low     <= 8'd0;
            wmask_high    <= 8'd0;
            rd_low        <= 64'd0;
            rd_high       <= 64'd0;
        end else begin
            // Capture new transaction when moving from IDLE → ISSUE_FIRST
            if (state == IDLE && next_state == ISSUE_FIRST) begin
                base_addr_reg <= caf_fifo_dout[27:0];
                is_write_reg  <= (caf_fifo_dout[30:28] == 3'b000);

                if (is_write_reg) begin
                    wdata_low  <= wdf_fifo_dout[63:0];              // lower 64-bit data
                    wdata_high <= wdf_fifo_dout[127:64];            // upper 64-bit data
                    wmask_low  <= wdf_fifo_dout[135:128];           // lower mask [135:128]
                    wmask_high <= wdf_fifo_dout[143:136];           // upper mask [143:136]
                end
            end

            // Capture first read burst (valid on app_rd_data_valid only)
            if (state == WAIT_RD_FIRST && app_rd_data_valid)
                rd_low <= app_rd_data;

            // Capture second read burst
            if (state == WAIT_RD_SECOND && app_rd_data_valid)
                rd_high <= app_rd_data;
        end
    end

endmodule