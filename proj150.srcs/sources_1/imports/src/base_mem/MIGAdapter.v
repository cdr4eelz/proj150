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
//TODO: Update this comment for accuracy!!!
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
    input  wire         ui_clk, //TODO: Rename ui_clk/rst to something like mig_clk/rst?
    input  wire         ui_clk_sync_rst,    // active-high reset for ui_clk domain

    // Command FIFO (mig_caf) - 31 bits {cmd[2:0], addr[27:0]}
//TODO: Only use 1 bit of caf for READ/WRITE (synth eleminates unused bits anyway)
    input  wire [30:0]  fifo_caf_dout,
    input  wire         fifo_caf_empty,
    input  wire         fifo_caf_valid,
    output wire         fifo_caf_rd_en,

    // Write Data FIFO (mig_wdf) - 144 bits
    // [143:128] = {mask_high[7:0], mask_low[7:0]}
    // [127:64]  = data_high[63:0]
    // [63:0]    = data_low[63:0]
    input  wire [143:0] fifo_wdf_dout,
    input  wire         fifo_wdf_empty,
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
    input  wire         app_rd_data_valid,
    // ignore app_rd_data_end
    output wire[ 3:0]   DBG_adapt
);

    // ────────────────────────────────────────────────
    // State encoding
    // ────────────────────────────────────────────────
    localparam  S_IDLE      = 3'd0,  // waiting for new command, latch addr & cmd
                S_READ1     = 3'd1,  // issuing first read (using FIFO addr)
                S_READ2     = 3'd2,  // issuing second read (base + 4)
                S_WRITECMD1 = 3'd3,  // issuing write command (before write data)
                S_WRITE1a   = 3'd4,  // LOW 64-bit data& 8-bit mask
                S_WRITE1b   = 3'd5,  // HIGH 64-bit data & 8-bit mask
                S_WRITECMD2 = 3'd6,  // Another go-around for 2nd 128-bits
                S_WRITE2a   = 3'd7,  // LOW (almost getting total to 256-bits)
                S_WRITE2b   = 3'd8;  // HIGH (end)
                // *** BE SURE THAT BIT WIDTH OF STATE REG IS SUFFICIENT! ***
    (* mark_debug = "true" *) reg [3:0] state; // Handle up to 8 states
    assign DBG_adapt = {state[3:0]};

    (* mark_debug = "true" *) reg [27:0] base_addr; // captured starting address from fifo_caf
    // Stash HIGH 8-bit mask & HIGH 64-bit data from fifo_wdf read for 2nd app_wdf write
    (* mark_debug = "true" *) reg [71:0] wr_stash_hi; //TODO: Split into separate regs (mask vs data)?

    //Our DDR3 unit is 16-bits ; FIFO chunk is 128-bits ; 128/16 = 8 ; 28-bit addr (of 16-bit units)
    localparam OFFSET_FOR_SECOND = 28'd8; // Mem offset for 2nd 128-bit chunk (to mimic old DDR2 behavior)

    // ────────────────────────────────────────────────
    // FSM + address register
    // ────────────────────────────────────────────────
    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin
            state     <= S_IDLE;
            base_addr <= 28'd0;
        end else begin
            // default holdS (UNNECESSARY but for clarity)
            state <= state;
            base_addr <= base_addr;
            wr_stash_hi <= wr_stash_hi;

            case (state)
                S_IDLE: begin // Capture new command from FIFO
                    if (fifo_caf_valid && fifo_caf_rd_en) begin
                        base_addr <= fifo_caf_dout[27:0];
                        if (fifo_caf_dout[30:28] == 3'b000) begin
                            state <= S_WRITECMD1;
                        end else begin
                            state <= S_READ1;
                        end
                    end
                end

                S_READ1: begin
                    if (app_rdy && app_en) begin
                        state <= S_READ2;
                    end
                end

                S_READ2: begin
                    if (app_rdy && app_en) begin
                        state <= S_IDLE;
                    end
                end

//TODO: Should we pass the write *DATA* *before* the write command???
                S_WRITECMD1: begin
                    if (app_rdy && app_en) state <= S_WRITE1a;
                end

                S_WRITE1a: begin
//TODO: Must be cautious of advancing FIFO or APP independently!!!
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITE1b;
                        // Stash high mask & data for followup write
                        wr_stash_hi <= {fifo_wdf_dout[143:136], fifo_wdf_dout[127:64]};
                        //TODO: Use "defines" for bit ranges???
                    end
                end

//TODO: 2 separate fifo reads, capture 2nd 64-bits of read, and double app writes!!!
                S_WRITE1b: begin
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITECMD2;
                    end
                end

                S_WRITECMD2: begin
                    if (app_rdy && app_en) state <= S_WRITE2a;
                end

                S_WRITE2a: begin
//TODO: Must be cautious of advancing FIFO or APP independently!!!
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITE2b;
                        // Stash high mask & data for followup write
                        wr_stash_hi <= {fifo_wdf_dout[143:136], fifo_wdf_dout[127:64]};
                        //TODO: Use "defines" for bit ranges???
                    end
                end

//TODO: 2 separate fifo reads, capture 2nd 64-bits of read, and double app writes!!!
                S_WRITE2b: begin
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_IDLE;
                    end
                end

//TODO: Need 2nd pass at writes (CMD2, 2a, 2b) to get full 256-bits written

                default: begin
                    state <= S_IDLE; //TODO: Fault state??? Fault recovery?
                end
            endcase
        end
    end

    wire is_wdf_state = (state == S_WRITE1a) || (state == S_WRITE1b) ||
                        (state == S_WRITE2a) || (state == S_WRITE2b);
                        // S_WRITECMD1/2 don't count (waf not wdf)
    wire write_ready = fifo_wdf_valid && app_wdf_rdy; // Valid does get asserted with FWFT FIFO
    wire is_second = (state == S_READ2) || (state == S_WRITE1b) || (state == S_WRITE2b);
    //TODO: the RIGHT1b/2b shouldn't fetch more from fifo_wdf (use wr_stash_hi only)
    assign fifo_wdf_rd_en   = is_wdf_state && fifo_wdf_valid; // Was "!empty"
    assign app_wdf_wren     = is_wdf_state && write_ready; //WAS: write_ready;
    assign app_wdf_data     = (is_second) ? wr_stash_hi[ 63:0  ] : fifo_wdf_dout[ 63:0  ];
    assign app_wdf_mask     = (is_second) ? wr_stash_hi[ 71:64 ] : fifo_wdf_dout[135:128];
    assign app_wdf_end      = (is_second && is_wdf_state); // depricated

    // ────────────────────────────────────────────────
    // Combinatorial outputs / control signals
    // ────────────────────────────────────────────────
    assign fifo_caf_rd_en  = ((state == S_IDLE) && fifo_caf_valid); // Was "!empty"
    assign app_cmd         = ((state == S_READ1) || (state == S_READ2))
                                ? 3'b001 : 3'b000;
    assign app_addr        = ((state == S_READ2) || (state == S_WRITECMD2))
                                ? (base_addr + OFFSET_FOR_SECOND) : base_addr;
    assign app_en          = (state == S_READ1) || (state == S_READ2) ||
                                (state == S_WRITECMD1) || (state == S_WRITECMD2);

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

// Read data path – A tiny FSM, with two states defined by "rd_phase" signal.
(* mark_debug = "true" *) reg         rd_phase;           // 0 = expect first 64-bit word, 1 = expect second
(* mark_debug = "true" *) reg [63:0]  rd_stashed;         // holds the first 64-bit word until second arrives

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
                rd_phase   <= 1'b1;
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
assign fifo_rdf_din = {app_rd_data, rd_stashed}; //TODO: Confirm HI/LO order is correct!!!

// Note: fifo_rdf_full is deliberately ignored per requirement.
// If the FIFO is full when we assert wr_en, data will be lost (MIG is not stalled).

endmodule
