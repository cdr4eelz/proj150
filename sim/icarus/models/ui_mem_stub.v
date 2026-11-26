// ui_mem_stub.v - fast behavioral model of the MIG 7-series native UI (simulation only).
// Lets the tester/sequencer be simulated in Icarus without any Xilinx IP.
//
// Models: random app_rdy / app_wdf_rdy back-pressure, a write-data FIFO (data may arrive before
// its command), byte masks (mask bit 1 = keep old byte), in-order reads with random latency.
// Checks UI protocol: write command without data, app_wdf_end != app_wdf_wren, misaligned
// app_addr (BL8 on x16 => app_addr[2:0] must be 0), rank bit app_addr[27] set.
// Memory: 2^DIRECT_LOG2 directly mapped beats + a 64-entry associative store for higher addresses.
//
// Fault injection (plusarg +INJECT=n):
//   0 none
//   1 flip data bit +INJECT_BIT (default 21) on reads of byte address +INJECT_ADDR (default 0x1230)
//   2 address aliasing: ignore app_addr[26] (top 128 MB folds onto the bottom 128 MB)
//   3 ignore write mask (all bytes always written)
// Other plusargs: +RDY_PCT=n (percent of cycles app_rdy/app_wdf_rdy are high; 0 = hang)
//                 +CALIB=n (cycles until init_calib_complete)
`timescale 1ps/1ps
module ui_mem_stub #(
    parameter integer DIRECT_LOG2 = 16,
    parameter integer CALIB_CYCLES = 300
) (
    input  wire          clk,
    input  wire          rst,
    output reg           init_calib_complete,
    input  wire [27:0]   app_addr,
    input  wire [2:0]    app_cmd,
    input  wire          app_en,
    output reg           app_rdy,
    input  wire [127:0]  app_wdf_data,
    input  wire [15:0]   app_wdf_mask,
    input  wire          app_wdf_wren,
    input  wire          app_wdf_end,
    output reg           app_wdf_rdy,
    output reg  [127:0]  app_rd_data,
    output reg           app_rd_data_valid,
    output reg           app_rd_data_end,
    output reg  [31:0]   protocol_errors
);
    integer inject, inject_bit, rdy_pct, calib_cycles;
    reg [31:0] inject_addr;
    initial begin
        if (!$value$plusargs("INJECT=%d", inject)) inject = 0;
        if (!$value$plusargs("INJECT_BIT=%d", inject_bit)) inject_bit = 21;
        if (!$value$plusargs("INJECT_ADDR=%h", inject_addr)) inject_addr = 32'h1230;
        if (!$value$plusargs("RDY_PCT=%d", rdy_pct)) rdy_pct = 70;
        if (!$value$plusargs("CALIB=%d", calib_cycles)) calib_cycles = CALIB_CYCLES;
    end

    // ---------------- storage
    reg [127:0] dmem [0:(1<<DIRECT_LOG2)-1];
    reg [23:0]  cam_tag  [0:63];
    reg [127:0] cam_data [0:63];
    reg         cam_v    [0:63];
    reg [5:0]   cam_ptr;
    integer i;
    initial begin
        for (i = 0; i < (1<<DIRECT_LOG2); i = i + 1) dmem[i] = {4{32'hDEAD_BEEF}};
        for (i = 0; i < 64; i = i + 1) begin cam_v[i] = 1'b0; cam_tag[i] = 0; cam_data[i] = 0; end
        cam_ptr = 0;
    end

    function [23:0] line_of(input [27:0] a);
        reg [27:0] ea;
        begin
            ea = a;
            if (inject == 2) ea[26] = 1'b0;
            line_of = ea[26:3];
        end
    endfunction

    function [127:0] mem_rd(input [23:0] line);
        integer k; reg found;
        begin
            mem_rd = {4{32'hDEAD_BEEF}};
            if (line < (1<<DIRECT_LOG2)) mem_rd = dmem[line];
            else begin
                found = 0;
                for (k = 0; k < 64; k = k + 1)
                    if (!found && cam_v[k] && cam_tag[k] == line) begin mem_rd = cam_data[k]; found = 1; end
            end
        end
    endfunction

    task mem_wr(input [23:0] line, input [127:0] d, input [15:0] m);
        reg [127:0] old, nw; integer b, k, hit;
        begin
            old = mem_rd(line);
            for (b = 0; b < 16; b = b + 1)
                nw[8*b +: 8] = (m[b] && inject != 3) ? old[8*b +: 8] : d[8*b +: 8];
            if (line < (1<<DIRECT_LOG2)) dmem[line] = nw;
            else begin
                hit = -1;
                for (k = 0; k < 64; k = k + 1) if (hit < 0 && cam_v[k] && cam_tag[k] == line) hit = k;
                if (hit < 0) begin hit = cam_ptr; cam_ptr = cam_ptr + 1; end
                cam_v[hit] = 1'b1; cam_tag[hit] = line; cam_data[hit] = nw;
            end
        end
    endtask

    // ---------------- write data FIFO
    reg [143:0] wq [0:15];
    integer wq_h, wq_t, wq_n;
    // ---------------- read return queue
    reg [127:0] rq_d [0:255];
    reg [63:0]  rq_t [0:255];
    integer rq_h, rq_tl, rq_n;
    reg [63:0] now, last_ready;
    integer calib_cnt;
    reg [127:0] rd;

    always @(posedge clk) begin
        if (rst) begin
            init_calib_complete <= 1'b0; calib_cnt = 0;
            app_rdy <= 1'b0; app_wdf_rdy <= 1'b0;
            app_rd_data_valid <= 1'b0; app_rd_data_end <= 1'b0; app_rd_data <= 0;
            wq_h = 0; wq_t = 0; wq_n = 0; rq_h = 0; rq_tl = 0; rq_n = 0;
            now = 0; last_ready = 0; protocol_errors <= 0;
        end else begin
            now = now + 1;
            if (calib_cnt < calib_cycles) calib_cnt = calib_cnt + 1;
            else init_calib_complete <= 1'b1;

            // write data accepted
            if (app_wdf_wren && app_wdf_rdy) begin
                if (app_wdf_end !== 1'b1) begin
                    $display("[stub] PROTOCOL: app_wdf_end != 1 on a single-beat (4:1 BL8 x16) write");
                    protocol_errors <= protocol_errors + 1;
                end
                wq[wq_t] = {app_wdf_mask, app_wdf_data}; wq_t = (wq_t + 1) % 16; wq_n = wq_n + 1;
            end
            // command accepted
            if (app_en && app_rdy) begin
                if (!init_calib_complete) begin
                    $display("[stub] PROTOCOL: command before init_calib_complete"); protocol_errors <= protocol_errors + 1;
                end
                if (app_addr[2:0] != 3'b000 || app_addr[27]) begin
                    $display("[stub] PROTOCOL: bad app_addr %h (must be 8-aligned, rank bit 0)", app_addr);
                    protocol_errors <= protocol_errors + 1;
                end
                if (app_cmd == 3'b000) begin
                    if (wq_n == 0) begin
                        $display("[stub] PROTOCOL: write command with no write data queued");
                        protocol_errors <= protocol_errors + 1;
                    end else begin
                        mem_wr(line_of(app_addr), wq[wq_h][127:0], wq[wq_h][143:128]);
                        wq_h = (wq_h + 1) % 16; wq_n = wq_n - 1;
                    end
                end else if (app_cmd == 3'b001) begin
                    rd = mem_rd(line_of(app_addr));
                    if (inject == 1 && {app_addr, 1'b0} == inject_addr[28:0]) rd[inject_bit] = ~rd[inject_bit];
                    rq_d[rq_tl] = rd;
                    last_ready = (now + 8 + ($random & 15) > last_ready + 1) ? now + 8 + ($random & 15) : last_ready + 1;
                    rq_t[rq_tl] = last_ready;
                    rq_tl = (rq_tl + 1) % 256; rq_n = rq_n + 1;
                end else begin
                    $display("[stub] PROTOCOL: unsupported app_cmd %b", app_cmd); protocol_errors <= protocol_errors + 1;
                end
            end
            // read data out (in order, cannot be stalled)
            if (rq_n > 0 && rq_t[rq_h] <= now) begin
                app_rd_data_valid <= 1'b1; app_rd_data_end <= 1'b1; app_rd_data <= rq_d[rq_h];
                rq_h = (rq_h + 1) % 256; rq_n = rq_n - 1;
            end else begin
                app_rd_data_valid <= 1'b0; app_rd_data_end <= 1'b0; app_rd_data <= {128{1'bx}};
            end
            // back-pressure for next cycle
            app_rdy     <= init_calib_complete && (($random & 32'h7FFF_FFFF) % 100 < rdy_pct) && rq_n < 200;
            app_wdf_rdy <= init_calib_complete && (($random & 32'h7FFF_FFFF) % 100 < rdy_pct) && wq_n < 14;
        end
    end
endmodule
