// fifo_async_fwft_model.v - behavioral stand-in for Xilinx FIFO Generator independent-clock
// FWFT FIFOs (simulation only). Write width WW, read width WW/RATIO (RATIO 1 or 4; for 4 the
// most significant 32 bits are read first, as FIFO Generator does for wide-to-narrow).
// Pointers cross clock domains through two flops, like the real FIFO's synchronizers.
// prog_full: write-side occupancy >= PF_THRESH (write words). prog_empty: read-side occupancy
// (read words) <= PE_THRESH. full when write-side occupancy reaches DEPTH.
`timescale 1ps/1ps
module fifo_async_fwft_model #(
    parameter integer WW = 128, RATIO = 1, DEPTH = 512,
    parameter integer PF_THRESH = 1 << 30, PE_THRESH = -1,
    parameter NAME = "fifo"
)(
    input  wire                 rst,
    input  wire                 wr_clk,
    input  wire                 wr_en,
    input  wire [WW-1:0]        din,
    output wire                 full,
    output wire                 almost_full,
    output wire                 prog_full,
    output reg                  wr_ack,
    output reg                  overflow,
    input  wire                 rd_clk,
    input  wire                 rd_en,
    output wire [WW/RATIO-1:0]  dout,
    output wire                 valid,
    output wire                 empty,
    output wire                 prog_empty,
    output reg                  underflow
);
    localparam integer RW = WW / RATIO;
    reg [WW-1:0] mem [0:DEPTH-1];
    integer wptr, rptr, rsub;            // rptr counts whole write words consumed
    integer wptr_s1, wptr_s2, rptr_s1, rptr_s2;
    integer overflow_count;

    wire [31:0] wocc = wptr - rptr_s2;   // write-side view
    wire [31:0] rocc = wptr_s2 - rptr;   // read-side view (write words, incl. partial)
    assign full        = (wocc >= DEPTH);
    assign almost_full = (wocc >= DEPTH - 1);
    assign prog_full   = (wocc >= PF_THRESH);
    assign valid       = (rocc > 0);
    assign empty       = !valid;
    assign prog_empty  = ((rocc * RATIO - rsub) <= PE_THRESH);
    wire [WW-1:0] word = mem[rptr % DEPTH];
    assign dout = word[WW-1 - rsub*RW -: RW];

    initial begin wptr = 0; rptr = 0; rsub = 0; wptr_s1 = 0; wptr_s2 = 0; rptr_s1 = 0; rptr_s2 = 0;
                  overflow_count = 0; wr_ack = 0; overflow = 0; underflow = 0; end

    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin wptr <= 0; rptr_s1 <= 0; rptr_s2 <= 0; wr_ack <= 0; overflow <= 0; end
        else begin
            rptr_s1 <= rptr; rptr_s2 <= rptr_s1;
            wr_ack   <= wr_en && !full;
            overflow <= wr_en && full;
            if (wr_en && !full) begin mem[wptr % DEPTH] <= din; wptr <= wptr + 1; end
            if (wr_en && full) begin
                overflow_count = overflow_count + 1;
                if (overflow_count <= 5) $display("[%0t] %0s: OVERFLOW (write while full, data lost)", $time, NAME);
            end
        end
    end
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin rptr <= 0; rsub <= 0; wptr_s1 <= 0; wptr_s2 <= 0; underflow <= 0; end
        else begin
            wptr_s1 <= wptr; wptr_s2 <= wptr_s1;
            underflow <= rd_en && !valid;
            if (rd_en && valid) begin
                if (rsub == RATIO - 1) begin rsub <= 0; rptr <= rptr + 1; end
                else rsub <= rsub + 1;
            end
        end
    end
endmodule
