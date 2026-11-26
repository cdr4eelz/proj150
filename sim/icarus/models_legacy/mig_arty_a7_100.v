// models_legacy/mig_arty_a7_100.v - stand-in for the ORIGINAL proj150 MIG (mig_b.prj: 2:1, 3300 ps,
// ui_clk 151.5 MHz, 64-bit app_wdf_data/app_rd_data, 8-bit mask), used only to re-run the untouched
// eee4d5d RTL. A shim maps the 2:1 UI onto ui_mem_stub (128-bit, one beat per command):
//   * write: two 64-bit beats (low first, app_wdf_end on the 2nd) are packed into one 128-bit beat;
//     a write command is only accepted once its packed data has been handed to the stub.
//   * read: each 128-bit stub beat is returned as two 64-bit beats on consecutive ui_clk cycles
//     (the real 2:1 MIG's peak rate: one 64-bit beat per ui_clk).
`timescale 1ps/1ps
module mig_arty_a7_100 (
    inout  wire [15:0] ddr3_dq, inout wire [1:0] ddr3_dqs_n, ddr3_dqs_p,
    output wire [13:0] ddr3_addr, output wire [2:0] ddr3_ba,
    output wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n,
    output wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, output wire [1:0] ddr3_dm,
    output wire init_calib_complete,
    output wire app_rdy, input wire app_en, input wire [2:0] app_cmd, input wire [27:0] app_addr,
    output wire app_wdf_rdy, input wire app_wdf_wren, input wire [63:0] app_wdf_data,
    input wire [7:0] app_wdf_mask, input wire app_wdf_end,
    output reg  app_rd_data_valid, output reg [63:0] app_rd_data, output reg app_rd_data_end,
    input wire app_sr_req, app_ref_req, app_zq_req, output wire app_sr_active, app_ref_ack, app_zq_ack,
    input wire sys_clk_i, sys_rst, clk_ref_i,
    output reg ui_clk, output reg ui_clk_sync_rst, output wire [11:0] device_temp
);
    assign {ddr3_addr, ddr3_ba, ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n} = 0;
    assign {ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, ddr3_dm} = 0;
    assign {app_sr_active, app_ref_ack, app_zq_ack} = 0;
    assign device_temp = 12'd0;
    initial ui_clk = 0;
    always #3300 ui_clk = ~ui_clk;          // 151.5 MHz
    reg [3:0] rcnt;
    initial ui_clk_sync_rst = 1'b1;
    always @(posedge ui_clk or negedge sys_rst)
        if (!sys_rst) begin rcnt <= 0; ui_clk_sync_rst <= 1'b1; end
        else if (rcnt != 4'hF) rcnt <= rcnt + 1; else ui_clk_sync_rst <= 1'b0;

    // ---- stub (128-bit UI)
    wire s_rdy, s_wdf_rdy, s_rd_valid, s_rd_end; wire [127:0] s_rd_data; wire [31:0] protocol_errors;
    reg  s_wdf_wren; reg [127:0] s_wdf_data; reg [15:0] s_wdf_mask;
    // ---- write packing
    reg        have_lo, pend;               // pend = packed beat waiting for the stub
    reg [63:0] lo_d; reg [7:0] lo_m;
    assign app_wdf_rdy = !pend;
    wire wdf_pushed = s_wdf_wren && s_wdf_rdy;
    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin have_lo <= 0; pend <= 0; s_wdf_wren <= 0; end
        else begin
            if (wdf_pushed) begin pend <= 0; s_wdf_wren <= 0; end
            if (app_wdf_wren && !pend) begin
                if (!have_lo) begin lo_d <= app_wdf_data; lo_m <= app_wdf_mask; have_lo <= 1; end
                else begin
                    s_wdf_data <= {app_wdf_data, lo_d}; s_wdf_mask <= {app_wdf_mask, lo_m};
                    s_wdf_wren <= 1; pend <= 1; have_lo <= 0;
                end
            end
        end
    end
    // write command must not overtake its data
    assign app_rdy = s_rdy && !(app_cmd == 3'b000 && (pend || have_lo));
    wire s_en = app_en && app_rdy;
    // ---- read splitting: queue of 128-bit beats, emitted as 2 x 64 bits
    reg [127:0] rq [0:1023]; integer rh, rt, half;
    initial begin rh = 0; rt = 0; half = 0; end
    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin rh = 0; rt = 0; half = 0; app_rd_data_valid <= 0; app_rd_data_end <= 0; end
        else begin
            if (s_rd_valid) begin rq[rt % 1024] = s_rd_data; rt = rt + 1; end
            if (rh != rt) begin
                app_rd_data_valid <= 1; app_rd_data <= half ? rq[rh % 1024][127:64] : rq[rh % 1024][63:0];
                app_rd_data_end <= half;
                if (half) begin half = 0; rh = rh + 1; end else half = 1;
            end else begin app_rd_data_valid <= 0; app_rd_data_end <= 0; end
        end
    end
    ui_mem_stub #(.DIRECT_LOG2(18), .CALIB_CYCLES(300)) stub (
        .clk(ui_clk), .rst(ui_clk_sync_rst), .init_calib_complete(init_calib_complete),
        .app_addr(app_addr), .app_cmd(app_cmd), .app_en(s_en), .app_rdy(s_rdy),
        .app_wdf_data(s_wdf_data), .app_wdf_mask(s_wdf_mask), .app_wdf_wren(s_wdf_wren),
        .app_wdf_end(s_wdf_wren), .app_wdf_rdy(s_wdf_rdy), .app_rd_data(s_rd_data),
        .app_rd_data_valid(s_rd_valid), .app_rd_data_end(s_rd_end), .protocol_errors(protocol_errors));
endmodule
