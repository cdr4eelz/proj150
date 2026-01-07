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
    output wire         app_wdf_end,         // depricated
    output wire         app_wdf_wren,
    input  wire         app_wdf_rdy,

    input  wire [63:0]  app_rd_data,
    input  wire         app_rd_data_valid
    // ignore app_rd_data_end
);

    // ────────────────────────────────────────────────
    // State encoding
    // ────────────────────────────────────────────────
    localparam  S_IDLE      = 3'd0,  // waiting for new command, latch addr & cmd
                S_READ1     = 3'd1,  // issuing first read (using FIFO addr)
                S_READ2     = 3'd2,  // issuing second read (base + 8)
                S_WRITECMD  = 3'd3,  // issuing write command (before write data)
                S_WRITE1a   = 3'd4,  // LOW 64-bit & 8-bit mask
                S_WRITE1b   = 3'd5,  // HIGH 64-bit & 8-bit mask
                S_WRITE2a   = 3'd6,  // LOW (getting total to 256-bits)
                S_WRITE2b   = 3'd7;  // HIGH (end)
                // are two more cycles of WRITE needed???? (2 for 64-bit adjust and 2 for full 256-bit write?)
                // BE SURE THAT BIT WIDTH OF STATE REG IS SUFFICIENT!
    reg [2:0] state; // Handle up to 8 states
    reg [27:0] base_addr;           // captured starting address

    // ────────────────────────────────────────────────
    // Combinatorial outputs / control signals
    // ────────────────────────────────────────────────
    assign fifo_caf_rd_en  = (state == S_IDLE); // Only accept new command in IDLE
    assign app_cmd         = ((state == S_READ1) || (state == S_READ2))
                                ? 3'b001 : 3'b000;
    assign app_addr        = (state == S_READ2)
                                ? (base_addr + 28'd8) : base_addr; // WRITECMD also uses base_addr
    assign app_en          = (state == S_READ1) || (state == S_READ2)
                                || (state == S_WRITECMD);

    // ────────────────────────────────────────────────
    // FSM + address register
    // ────────────────────────────────────────────────
    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin
            state     <= S_IDLE;
            base_addr <= 28'd0;
        end else begin
            state <= state;  // default hold
            base_addr <= base_addr; // default hold
            case (state)
                S_IDLE: begin // Capture new command from FIFO
                    if (fifo_caf_valid && fifo_caf_rd_en) begin
                        base_addr <= fifo_caf_dout[27:0];
                        if (fifo_caf_dout[30:28] == 3'b001) begin
                            state <= S_READ1;
                        end else begin
                            state <= S_WRITE1a;
                        end
                    end
                end

                S_READ1: begin
                    if (app_rdy && app_en) begin
                        state    <= S_READ2;
                    end
                end

                S_READ2: begin
                    if (app_rdy && app_en) begin
                        state    <= S_IDLE;
                    end
                end

                S_WRITECMD: begin
                    if (app_rdy && app_en) begin // ISSUING WRITE COMMAND ONLY
                        state    <= S_WRITE1a;
                    end
                end

// WATCH OUT BECAUSE EACH ELEMENT COULD FIRE INDEPENDENTLY! FIFO, WDF, APP 
                S_WRITE1a: begin
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state    <= S_WRITE1b;
                    end
                end

                S_WRITE1b: begin
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state    <= S_IDLE; // OR S_WRITECMD IF MORE WRITES NEEDED??? OR 2 more WRITES???
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

wire is_right_state = (state == S_WRITE1a) || (state == S_WRITE1b) ||
                      (state == S_WRITE2a) || (state == S_WRITE2b);
wire write_ready = fifo_wdf_valid && app_wdf_rdy;
wire is_second = (state == S_READ2) && (state == S_WRITE2a) || (state == S_WRITE2b);
assign fifo_wdf_rd_en = write_ready && is_right_state;
assign app_wdf_wren = write_ready && is_right_state;
assign app_wdf_data = (is_second) ? fifo_wdf_dout[127:64] : fifo_wdf_dout[63:0];
assign app_wdf_mask = (is_second) ? fifo_wdf_dout[143:136] : fifo_wdf_dout[135:128];
assign app_wdf_end = (state == S_WRITE2b); // depricated
//    output wire [63:0]  app_wdf_data, // Select high or low 64 bits based on state
//    output wire [7:0]   app_wdf_mask, // Select high or low 8 bits based on state
//    output wire         app_wdf_wren, // Assert on write states
//    input  wire         app_wdf_rdy,  // Advance 

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

// Read data path – A tiny FSM, with two states defined by "rd_phase" signal.
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