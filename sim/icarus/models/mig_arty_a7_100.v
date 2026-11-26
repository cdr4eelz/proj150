// mig_arty_a7_100.v - simulation stand-in for the MIG IP (4:1, 128-bit native UI): makes an
// 81.25 MHz ui_clk, holds ui_clk_sync_rst while sys_rst (ACTIVE LOW) is low, and puts the
// behavioral UI model ui_mem_stub (from arty-mig-test, unchanged) behind the app_* ports.
`timescale 1ps/1ps
`ifndef STUB_LOG2
 `define STUB_LOG2 18   // direct-mapped lines of 16 B: 2^18 = 4 MB; the GPU phase (-DSTUB_LOG2=21) needs 32 MB for frames 2..5
`endif
module mig_arty_a7_100 (
    inout  wire [15:0] ddr3_dq, inout wire [1:0] ddr3_dqs_n, ddr3_dqs_p,
    output wire [13:0] ddr3_addr, output wire [2:0] ddr3_ba,
    output wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n,
    output wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, output wire [1:0] ddr3_dm,
    output wire init_calib_complete,
    output wire app_rdy, input wire app_en, input wire [2:0] app_cmd, input wire [27:0] app_addr,
    output wire app_wdf_rdy, input wire app_wdf_wren, input wire [127:0] app_wdf_data,
    input wire [15:0] app_wdf_mask, input wire app_wdf_end,
    output wire app_rd_data_valid, output wire [127:0] app_rd_data, output wire app_rd_data_end,
    input wire app_sr_req, app_ref_req, app_zq_req, output wire app_sr_active, app_ref_ack, app_zq_ack,
    input wire sys_clk_i, sys_rst, clk_ref_i,
    output reg ui_clk, output reg ui_clk_sync_rst, output wire [11:0] device_temp
);
    assign {ddr3_addr, ddr3_ba, ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n} = 0;
    assign {ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, ddr3_dm} = 0;
    assign {app_sr_active, app_ref_ack, app_zq_ack} = 0;
    assign device_temp = 12'd0;
    initial ui_clk = 0;
    always #6154 ui_clk = ~ui_clk;
    reg [3:0] rcnt;
    always @(posedge ui_clk or negedge sys_rst)
        if (!sys_rst) begin rcnt <= 0; ui_clk_sync_rst <= 1'b1; end
        else if (rcnt != 4'hF) rcnt <= rcnt + 1; else ui_clk_sync_rst <= 1'b0;
    initial ui_clk_sync_rst = 1'b1;
    wire [31:0] protocol_errors;
    ui_mem_stub #(.DIRECT_LOG2(`STUB_LOG2), .CALIB_CYCLES(300)) stub (
        .clk(ui_clk), .rst(ui_clk_sync_rst), .init_calib_complete(init_calib_complete),
        .app_addr(app_addr), .app_cmd(app_cmd), .app_en(app_en), .app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data), .app_wdf_mask(app_wdf_mask), .app_wdf_wren(app_wdf_wren),
        .app_wdf_end(app_wdf_end), .app_wdf_rdy(app_wdf_rdy), .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid), .app_rd_data_end(app_rd_data_end),
        .protocol_errors(protocol_errors));
endmodule
