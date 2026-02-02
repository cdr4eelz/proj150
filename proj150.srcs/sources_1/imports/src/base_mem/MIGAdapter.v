//TODO: Simplify & check this comment for accuracy!!!
//=============================================================================
// Module: MIGAdapter
// Purpose: Interface adapter between 128-bit transaction FIFOs (CPU domain)
//          and 64-bit MIG "standard" (non-AXI) user interface (ui_clk domain).
//          ** The goal is to reproduce the old behavior of the DDR2 access
//             on the original Xilinx XUP board, avoiding alteration of many
//             modules elsewhere in the project. This means that 256-bits are
//             transferred in total, for each read or write. **
// Features:
// + Double requests (R/W) by injecting a 2nd command at an offset address:
// -   This mimics the old setup where one request turned into two 128-bit
//     responses (or the reverse for writes). Current MIG issues half that.
// + Current MIG uses 2:1 clock ratio, making each R/W 64-bits wide:
// -   Each write reaches the adapter via the "wdf" FIFO and each read leaves
//     the "rdf" FIFO. The FIFOs are 128-bits wide, so writes are split into
//     two 64-bit MIG writes, and reads are combined from two 64-bit MIG reads.
// + Each "channel" (caf, wdf, rdf) is independent in the adapter:
// -   E.g. "FIFO CAF" (command & address FIFO) links with "app_{en,rdy, etc.}"
// -   "FIFO WDF" (write data FIFO) links with "app_wdf_{wren,rdy,etc.}"
// -   "FIFO RDF" (read data FIFO) links with "app_rd_data{valid,etc.}"
// + Respects back-pressure (app_rdy, app_wdf_rdy) but app_rd_data_valid will
//     not wait and the "rdf" FIFO MUST accept the data or lose it.
// + app_rd_data_end & app_wdf_end are deprecated but wdr_end is generated.
//=============================================================================

module MIGAdapter (
    input  wire         clk_mig_ui,    // clock for MIG user interface
    input  wire         rst_mig_ui,    // active-high reset for clk_mig_ui domain

    // Command FIFO (mig_caf) - 31 bits {cmd[2:0], addr[27:0]}
    output wire         fifo_caf_rd_en,
    input  wire         fifo_caf_valid,
    input  wire [30:0]  fifo_caf_dout,
    input  wire         fifo_caf_empty,

    // Write Data FIFO (mig_wdf) - 144 bits
    // [143:128] = {mask_high[7:0], mask_low[7:0]}
    // [127:64]  = data_high[63:0]
    // [63:0]    = data_low[63:0]
    output wire         fifo_wdf_rd_en,
    input  wire         fifo_wdf_valid,
    input  wire [143:0] fifo_wdf_dout,
    input  wire         fifo_wdf_empty,

    // Read Data FIFO (mig_rdf) - 128-bit pure read data
    output wire         fifo_rdf_wr_en,
    output wire [127:0] fifo_rdf_din,
    input  wire         fifo_rdf_full,

    // MIG standard interface (UG586)
    input  wire         app_rdy,
    output wire         app_en,
    output wire [2:0]   app_cmd,            // 000=WRITE, 001=READ
    output wire [27:0]  app_addr,

    output wire [63:0]  app_wdf_data,
    output wire [7:0]   app_wdf_mask,
    output wire         app_wdf_end,         // depricated
    output wire         app_wdf_wren,
    input  wire         app_wdf_rdy,

    input  wire         app_rd_data_valid, //NOTE: No app_rd_data_rdy signal!
    input  wire [63:0]  app_rd_data,
    input  wire         app_rd_data_end,

    output wire[ 3:0]   DBG_adapt
);

    //Our DDR3 unit is 16-bits ; FIFO chunk is 128-bits ; 128/16 = 8 ; 28-bit addr (of 16-bit units)
    localparam OFFSET_ADDR_128bit = 28'd8; // Mem offset for 2nd 128-bit chunk (to mimic old DDR2 behavior)
    // Offset 8 seems appropriate. Each 16-bit unit is 2 bytes, so 8 units = 16 bytes = 128 bits.
    // This is the offset of DDR3 addresses to get to the next 128-bit block, within the 256-bit total.

    // ────────────────────────────────────────────────
    // State encoding
    // ────────────────────────────────────────────────
    localparam  S_IDLE      = 4'b0000,  // waiting for new command, snag addr & cmd
                S_READ1     = 4'b0001,  // issuing first read (using FIFO addr)
                S_READ2     = 4'b0010,  // issuing second read (base + offset)
                S_WRITE1a   = 4'b0011,  // LOW 64-bit data & 8-bit mask
                S_WRITE1b   = 4'b0100,  // HIGH 64-bit data & 8-bit mask
                S_WRITECMD1 = 4'b0101,  // issuing write command (AFTER write data)
                S_WRITE2a   = 4'b0110,  // LOW (almost getting total to 256-bits)
                S_WRITE2b   = 4'b0111,  // HIGH (end)
                S_WRITECMD2 = 4'b1000;  // Another go-around for 2nd 128-bits
                // *** BE SURE THAT BIT WIDTH OF STATE REG IS SUFFICIENT! ***
    (* mark_debug = "true" *) // Need to debug state machine's states as enumerated values
    reg [3:0] state; // Handle up to 16 states
    assign DBG_adapt = {state[3:0]};
    
    reg [27:0] base_addr; // captured starting address from fifo_caf
    // Stash HIGH 8-bit mask & HIGH 64-bit data from fifo_wdf read for 2nd app_wdf write
    reg [ 7:0] wr_stash_mask; // From 72-bit concat of {mask_high[7:0], data_high[63:0]}
    reg [63:0] wr_stash_data;

    //TODO: This entire section splits into two state-machines (WDF vs CAF)
    //TODO: Eliminate two-step CAF handoff. Perform direct FIFO => MIG/APP in first cycle.
    //TODO: CAF and WDF FIFOs should be advanced independently, based on their own ready/valid signals.
    //TODO: Read vs Write can be identical handling... just double the transaction with matching cmds.

    always @(posedge clk_mig_ui) begin
        if (rst_mig_ui) begin
            state <= S_IDLE;
            //base_addr <= 0; *** Minimize logic on reset ***
            //{wr_stash_mask, wr_stash_data} <= 0; *** Likewise ***
        end else begin
            // default holds (UNNECESSARY but for clarity/intent)
            state <= state;
            base_addr <= base_addr;
            wr_stash_mask <= wr_stash_mask;
            wr_stash_data <= wr_stash_data;

            case (state)
                S_IDLE: begin // Capture new command from FIFO
                    if (fifo_caf_valid && fifo_caf_rd_en) begin
                        base_addr <= fifo_caf_dout[27:0];
                        if (fifo_caf_dout[30:28] == 3'b000) begin
                            state <= S_WRITE1a;
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

                S_WRITE1a: begin
//NOTE: Must be cautious of advancing FIFO or APP independently!!!
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITE1b;
                        // Stash high mask & data for followup write
                        wr_stash_mask <= fifo_wdf_dout[143:136];
                        wr_stash_data <= fifo_wdf_dout[127:64 ];
                    end
                end
//TODO: Perform simultaneous write-data and command??? (Merge S_WRITExb with S_WRITECMDx)
                S_WRITE1b: begin
                    if (app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITECMD1;
                    end
                end

                S_WRITECMD1: begin
                    if (app_rdy && app_en) state <= S_WRITE2a;
                end

                S_WRITE2a: begin
//NOTE: Must be cautious of advancing FIFO or APP independently!!!
                    if (fifo_wdf_valid && fifo_wdf_rd_en &&
                            app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITE2b;
                        // Stash high mask & data for followup write
                        wr_stash_mask <= fifo_wdf_dout[143:136];
                        wr_stash_data <= fifo_wdf_dout[127:64 ];
                    end
                end

                S_WRITE2b: begin
                    if (app_wdf_rdy && app_wdf_wren) begin
                        state <= S_WRITECMD2;
                    end
                end

                S_WRITECMD2: begin
                    if (app_rdy && app_en) state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE; //TODO: Fault state??? Fault recovery?
                end
            endcase
        end
    end

    wire is_wdf_first   = (state == S_WRITE1a) || (state == S_WRITE2a);
    wire is_wdf_second  = (state == S_WRITE1b) || (state == S_WRITE2b);
    // When reading fifo while writing to MIG, ensure BOTH are ready simulataneously (Requires FIFO FWFT)

    // Utilize categorizations above to drive key output signals:
    assign fifo_wdf_rd_en   = fifo_wdf_valid && app_wdf_rdy && is_wdf_first;
    assign app_wdf_wren     = app_wdf_rdy && (is_wdf_second || (is_wdf_first && fifo_wdf_valid));
    // MUX between stashed data/mask and direct FIFO data/mask (could do one at a time for safety)
    assign app_wdf_mask     = (is_wdf_second) ? wr_stash_mask : fifo_wdf_dout[135:128];
    assign app_wdf_data     = (is_wdf_second) ? wr_stash_data : fifo_wdf_dout[ 63:0  ];
    assign app_wdf_end      = (is_wdf_second); // Depricated signal, but we still set it

    assign fifo_caf_rd_en   = ((state == S_IDLE) && fifo_caf_valid);
    assign app_cmd          = ((state == S_READ1) || (state == S_READ2))
                                ? 3'b001 : 3'b000;
    assign app_addr         = ((state == S_READ2) || (state == S_WRITECMD2))
                                ? (base_addr + OFFSET_ADDR_128bit) : base_addr;
    assign app_en           = (state == S_READ1) || (state == S_READ2) ||
                                (state == S_WRITECMD1) || (state == S_WRITECMD2);

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

// Read data path – A tiny FSM, with two states defined by "rd_phase" signal.
reg         rd_phase;           // 0 = expect first 64-bit word, 1 = expect second
reg [63:0]  rd_stashed;         // holds the first 64-bit word until second arrives

// Reset behavior + state / data update
always @(posedge clk_mig_ui) begin
    if (rst_mig_ui) begin
        rd_phase    <= 1'b0;            // start expecting first word
        rd_stashed  <= 64'h0;           // clear staged data
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

// Tap into signals for ILA debugging. Prefix names to identify module:
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_caf_rd_en = fifo_caf_rd_en;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_caf_valid = fifo_caf_valid;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_caf_empty = fifo_caf_empty;
    (* mark_debug = "true" *) wire [ 30:0] TAP_ADP_fifo_caf_dout  = fifo_caf_dout;

    (* mark_debug = "true" *) wire         TAP_ADP_fifo_wdf_empty = fifo_wdf_empty;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_wdf_rd_en = fifo_wdf_rd_en;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_wdf_valid = fifo_wdf_valid;
    (* mark_debug = "true" *) wire [143:0] TAP_ADP_fifo_wdf_dout  = fifo_wdf_dout;

    (* mark_debug = "true" *) wire [127:0] TAP_ADP_fifo_rdf_din   = fifo_rdf_din;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_rdf_wr_en = fifo_rdf_wr_en;
    (* mark_debug = "true" *) wire         TAP_ADP_fifo_rdf_full  = fifo_rdf_full;

    (* mark_debug = "true" *) wire         TAP_ADP_app_rdy        = app_rdy;
    (* mark_debug = "true" *) wire         TAP_ADP_app_en         = app_en;
    (* mark_debug = "true" *) wire [  2:0] TAP_ADP_app_cmd        = app_cmd;
    (* mark_debug = "true" *) wire [ 27:0] TAP_ADP_app_addr       = app_addr;

    (* mark_debug = "true" *) wire         TAP_ADP_app_wdf_wren   = app_wdf_wren;
    (* mark_debug = "true" *) wire         TAP_ADP_app_wdf_rdy    = app_wdf_rdy;
    (* mark_debug = "true" *) wire         TAP_ADP_app_wdf_end    = app_wdf_end;
    (* mark_debug = "true" *) wire [ 63:0] TAP_ADP_app_wdf_data   = app_wdf_data;
    (* mark_debug = "true" *) wire [  7:0] TAP_ADP_app_wdf_mask   = app_wdf_mask;
    (* mark_debug = "true" *) wire [ 63:0] TAP_ADP_app_rd_data    = app_rd_data;
    (* mark_debug = "true" *) wire         TAP_ADP_app_rd_data_valid  = app_rd_data_valid;
    (* mark_debug = "true" *) wire         TAP_ADP_app_rd_data_end    = app_rd_data_end;

    (* mark_debug = "true" *) wire         TAP_ADP_rd_phase       = rd_phase;
    (* mark_debug = "true" *) wire [ 63:0] TAP_ADP_rd_stashed     = rd_stashed;
    (* mark_debug = "true" *) wire [ 27:0] TAP_ADP_base_addr      = base_addr;
    (* mark_debug = "true" *) wire [  7:0] TAP_ADP_wr_stash_mask  = wr_stash_mask;
    (* mark_debug = "true" *) wire [ 63:0] TAP_ADP_wr_stash_data  = wr_stash_data;
    (* mark_debug = "true" *) wire [  3:0] TAP_ADP_state          = state;

    (* mark_debug = "true" *) wire         TAP_ADP_is_wdf_second  = is_wdf_second;
    (* mark_debug = "true" *) wire         TAP_ADP_is_wdf_first   = is_wdf_first;

endmodule
