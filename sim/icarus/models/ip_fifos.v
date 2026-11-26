// ip_fifos.v - simulation stand-ins for the FIFO Generator IPs used by MemoryDDR/PixelFeeder.
// Thresholds follow the IP settings: mig_rdf prog_full 400 (scripts/ip/mig_fifos.tcl);
// pixel_fifo prog_full / prog_empty from PF_FULL / PF_EMPTY (defaults = current IP settings).
`timescale 1ps/1ps
`ifndef PIXEL_PF_FULL
 `define PIXEL_PF_FULL 448   // scripts/ip/pixel_fifo.tcl
`endif
`ifndef PIXEL_PF_EMPTY
 `define PIXEL_PF_EMPTY 1600  // scripts/ip/pixel_fifo.tcl
`endif
module mig_caf (input wire rst, wr_clk, wr_en, input wire [30:0] din, output wire full, output wire wr_ack,
                input wire rd_clk, rd_en, output wire [30:0] dout, output wire valid, empty, underflow);
    fifo_async_fwft_model #(.WW(31), .DEPTH(512), .NAME("mig_caf")) f (
        .rst(rst), .wr_clk(wr_clk), .wr_en(wr_en), .din(din), .full(full), .almost_full(), .prog_full(),
        .wr_ack(wr_ack), .overflow(), .rd_clk(rd_clk), .rd_en(rd_en), .dout(dout), .valid(valid),
        .empty(empty), .prog_empty(), .underflow(underflow));
endmodule
module mig_wdf (input wire rst, wr_clk, wr_en, input wire [143:0] din, output wire full, output wire wr_ack,
                input wire rd_clk, rd_en, output wire [143:0] dout, output wire valid, empty, underflow);
    fifo_async_fwft_model #(.WW(144), .DEPTH(512), .NAME("mig_wdf")) f (
        .rst(rst), .wr_clk(wr_clk), .wr_en(wr_en), .din(din), .full(full), .almost_full(), .prog_full(),
        .wr_ack(wr_ack), .overflow(), .rd_clk(rd_clk), .rd_en(rd_en), .dout(dout), .valid(valid),
        .empty(empty), .prog_empty(), .underflow(underflow));
endmodule
module mig_rdf (input wire rst, wr_clk, wr_en, input wire [127:0] din, output wire full, output wire wr_ack,
                output wire prog_full,
                input wire rd_clk, rd_en, output wire [127:0] dout, output wire valid, empty, underflow);
    fifo_async_fwft_model #(.WW(128), .DEPTH(512), .PF_THRESH(400), .NAME("mig_rdf")) f (
        .rst(rst), .wr_clk(wr_clk), .wr_en(wr_en), .din(din), .full(full), .almost_full(), .prog_full(prog_full),
        .wr_ack(wr_ack), .overflow(), .rd_clk(rd_clk), .rd_en(rd_en), .dout(dout), .valid(valid),
        .empty(empty), .prog_empty(), .underflow(underflow));
endmodule
module pixel_fifo (input wire rst, wr_clk, wr_en, input wire [127:0] din,
                   output wire full, almost_full, prog_full, output wire wr_rst_busy,
                   input wire rd_clk, rd_en, output wire [31:0] dout, output wire empty, prog_empty, valid,
                   output wire rd_rst_busy, output wire wr_ack, overflow, underflow);
    assign wr_rst_busy = 1'b0, rd_rst_busy = 1'b0;
    fifo_async_fwft_model #(.WW(128), .RATIO(4), .DEPTH(512), .PF_THRESH(`PIXEL_PF_FULL),
                            .PE_THRESH(`PIXEL_PF_EMPTY), .NAME("pixel_fifo")) f (
        .rst(rst), .wr_clk(wr_clk), .wr_en(wr_en), .din(din), .full(full), .almost_full(almost_full),
        .prog_full(prog_full), .wr_ack(wr_ack), .overflow(overflow), .rd_clk(rd_clk), .rd_en(rd_en),
        .dout(dout), .valid(valid), .empty(empty), .prog_empty(prog_empty), .underflow(underflow));
endmodule
