`timescale 1ns/1ps
// Behavioral model of the uarx_fifo IP (ip/uarx_fifo.tcl; ISE core_ip/extra/uarx_fifo): 8 x 16384,
// common clock, first-word fall-through, valid/overflow, prog_full at 15500, async reset.
module uarx_fifo #(parameter DEPTH = 16384, PROG_FULL = 15500) (
    input clk, rst,
    input [7:0] din, input wr_en, rd_en,
    output [7:0] dout, output full, overflow, empty, valid, prog_full
);
    reg [7:0] mem [0:DEPTH-1];
    reg [14:0] wp = 0, rp = 0;
    reg [15:0] cnt = 0;
    reg ovf = 0;
    wire do_rd = rd_en && cnt != 0;
    wire do_wr = wr_en && cnt != DEPTH;
    always @(posedge clk or posedge rst) begin
        if (rst) begin wp <= 0; rp <= 0; cnt <= 0; ovf <= 0; end
        else begin
            if (do_wr) begin mem[wp[13:0]] <= din; wp <= wp + 1; end
            if (do_rd) rp <= rp + 1;
            cnt <= cnt + do_wr - do_rd;
            ovf <= wr_en && !do_wr;
        end
    end
    assign dout = mem[rp[13:0]];
    assign valid = (cnt != 0), empty = (cnt == 0), full = (cnt == DEPTH);
    assign prog_full = (cnt >= PROG_FULL), overflow = ovf;
endmodule
