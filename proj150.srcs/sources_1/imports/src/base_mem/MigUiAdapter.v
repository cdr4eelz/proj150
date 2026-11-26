//=============================================================================
// Module: MigUiAdapter
// Purpose: Connects the CS150 clock-crossing FIFOs (mig_caf / mig_wdf / mig_rdf) to the
//          MIG 7-series NATIVE user interface, configured 4:1 / BL8 / x16 DDR3L, i.e. ONE
//          128-bit beat per command (the configuration proven on hardware by arty-mig-test).
//          Entirely in the clk_mig_ui (ui_clk, 81.25 MHz) domain. Replaces MIGAdapter.v
//          (written for the 2:1 / 64-bit UI).
//
// Contract kept from the old DDR2 design (so Cache/RequestController/GPU are unchanged):
//   * One mig_caf entry {cmd[2:0], addr[27:0]} = one 256-bit access = TWO 128-bit beats:
//     a MIG command at addr and one at addr+8 (app_addr is in 16-bit units, 8 units = 16 B).
//   * A write consumes TWO mig_wdf entries {mask[15:0], data[127:0]}, first one for addr,
//     second for addr+8. mask bit 1 = byte NOT written (MIG convention; Cache.v inverts).
//   * A read produces TWO mig_rdf entries, in order (the native UI returns reads in order).
//   * addr[27] is the MIG rank bit and must be 0 (byte address >> 1 gives 27 bits for 256 MB).
//
// Read credits: MIG read data can NOT be back-pressured. The old adapter wrote mig_rdf without
//   checking it, so when PixelFeeder flooded the memory with reads the FIFO overflowed, beats
//   were lost, and RequestController (which matches data to requesters by counting) handed every
//   later read to the wrong client. Here a read command is only issued while
//      (beats in flight) < MAX_INFLIGHT  AND  mig_rdf prog_full is low,
//   with prog_full set (ip/mig_rdf.tcl) far enough below the depth that every beat in
//   flight always has room. CREDIT_EN=0 restores the old unthrottled behavior (sim only).
// rdf_overflow is a sticky flag (until rst) that must never assert: it goes to an LED.
//=============================================================================
`default_nettype none
module MigUiAdapter #(
    parameter integer MAX_INFLIGHT = 32,   // read beats issued but not yet returned
    parameter         CREDIT_EN    = 1     // 0 = old behavior (no read flow control), sim only
)(
    input  wire         clk,               // ui_clk
    input  wire         rst,               // ui_clk_sync_rst (active high)

    // Command FIFO (FWFT) {cmd[2:0], addr[27:0]}
    output wire         caf_rd_en,
    input  wire         caf_valid,
    input  wire [30:0]  caf_dout,
    // Write-data FIFO (FWFT) {mask[15:0], data[127:0]}
    output wire         wdf_rd_en,
    input  wire         wdf_valid,
    input  wire [143:0] wdf_dout,
    // Read-data FIFO (write side)
    output wire         rdf_wr_en,
    output wire [127:0] rdf_din,
    input  wire         rdf_full,
    input  wire         rdf_prog_full,

    // MIG native UI (UG586)
    input  wire         init_calib_complete,
    output reg  [27:0]  app_addr,
    output reg  [2:0]   app_cmd,
    output reg          app_en,
    input  wire         app_rdy,
    output reg  [127:0] app_wdf_data,
    output reg  [15:0]  app_wdf_mask,
    output reg          app_wdf_wren,
    output wire         app_wdf_end,
    input  wire         app_wdf_rdy,
    input  wire [127:0] app_rd_data,
    input  wire         app_rd_data_valid,

    output reg          rdf_overflow,      // sticky: read beat arrived while mig_rdf was full
    output wire [3:0]   dbg_state
);
    localparam [2:0] CMD_WRITE = 3'b000, CMD_READ = 3'b001;
    localparam [2:0] S_IDLE = 3'd0, S_WLOAD = 3'd1, S_WDATA = 3'd2, S_WCMD = 3'd3,
                     S_RCMD = 3'd4, S_RWAIT = 3'd5;
    localparam [27:0] HALF_OFFSET = 28'd8;  // 128 bits = 8 x 16-bit units

    reg [2:0]  state;
    reg        half;                         // 0 = first 128 bits, 1 = second
    reg [27:0] base_addr;
    reg [7:0]  inflight;                     // read beats issued, not yet returned

    assign app_wdf_end = app_wdf_wren;       // 4:1, BL8, x16: every write is a single beat
    assign dbg_state   = {half, state};

    // FWFT FIFOs: rd_en pops the word currently on dout.
    assign caf_rd_en = (state == S_IDLE) && caf_valid && init_calib_complete;
    assign wdf_rd_en = (state == S_WLOAD) && wdf_valid;

    // Read data goes straight into mig_rdf (one entry per beat, in order).
    assign rdf_wr_en = app_rd_data_valid;
    assign rdf_din   = app_rd_data;

    wire read_credit = !CREDIT_EN || ((inflight < MAX_INFLIGHT) && !rdf_prog_full);
    wire rd_issue    = (state == S_RWAIT) && app_rdy;   // read command accepted this cycle

    always @(posedge clk) begin
        if (rst) begin
            inflight     <= 8'd0;
            rdf_overflow <= 1'b0;
        end else begin
            case ({rd_issue, app_rd_data_valid})
                2'b10:   inflight <= inflight + 8'd1;
                2'b01:   inflight <= inflight - 8'd1;
                default: inflight <= inflight;
            endcase
            if (app_rd_data_valid && rdf_full) rdf_overflow <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; half <= 1'b0; base_addr <= 28'd0;
            app_en <= 1'b0; app_cmd <= CMD_READ; app_addr <= 28'd0;
            app_wdf_wren <= 1'b0; app_wdf_data <= 128'd0; app_wdf_mask <= 16'hFFFF;
        end else begin
            case (state)
            S_IDLE: if (caf_rd_en) begin
                base_addr <= caf_dout[27:0];
                half      <= 1'b0;
                state     <= (caf_dout[30:28] == CMD_WRITE) ? S_WLOAD : S_RCMD;
            end
            // ---- write: data beat first, then its command (as in arty-mig-test)
            S_WLOAD: if (wdf_valid) begin
                app_wdf_data <= wdf_dout[127:0];
                app_wdf_mask <= wdf_dout[143:128];
                app_wdf_wren <= 1'b1;
                state        <= S_WDATA;
            end
            S_WDATA: if (app_wdf_rdy) begin
                app_wdf_wren <= 1'b0;
                app_en       <= 1'b1;
                app_cmd      <= CMD_WRITE;
                app_addr     <= half ? (base_addr + HALF_OFFSET) : base_addr;
                state        <= S_WCMD;
            end
            S_WCMD: if (app_rdy) begin
                app_en <= 1'b0;
                if (!half) begin half <= 1'b1; state <= S_WLOAD; end
                else       state <= S_IDLE;
            end
            // ---- read: one command per beat, only with a free read credit
            S_RCMD: if (read_credit) begin
                app_en   <= 1'b1;
                app_cmd  <= CMD_READ;
                app_addr <= half ? (base_addr + HALF_OFFSET) : base_addr;
                state    <= S_RWAIT;
            end
            S_RWAIT: if (app_rdy) begin
                app_en <= 1'b0;
                if (!half) begin half <= 1'b1; state <= S_RCMD; end
                else       state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
