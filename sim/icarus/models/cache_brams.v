// cache_brams.v - simulation stand-ins for the Block Memory Generator simple-dual-port RAMs
// used by Cache.v (port A write, port B read, 1-cycle registered read, no output registers).
`timescale 1ps/1ps
module cache_data_blk_ram (input wire clka, ena, input wire [31:0] wea, input wire [7:0] addra,
                           input wire [255:0] dina, input wire clkb, rstb, enb, input wire [7:0] addrb,
                           output reg [255:0] doutb);
    reg [255:0] mem [0:255]; integer i, b;
    initial begin for (i = 0; i < 256; i = i + 1) mem[i] = 256'd0; doutb = 0; end
    always @(posedge clka) if (ena) for (b = 0; b < 32; b = b + 1) if (wea[b]) mem[addra][8*b +: 8] <= dina[8*b +: 8];
    always @(posedge clkb) if (rstb) doutb <= 0; else if (enb) doutb <= mem[addrb];
endmodule
module cache_tag_blk_ram (input wire clka, ena, input wire [0:0] wea, input wire [7:0] addra,
                          input wire [20:0] dina, input wire clkb, rstb, enb, input wire [7:0] addrb,
                          output reg [20:0] doutb);
    reg [20:0] mem [0:255]; integer i;
    initial begin for (i = 0; i < 256; i = i + 1) mem[i] = 21'd0; doutb = 0; end
    always @(posedge clka) if (ena && wea[0]) mem[addra] <= dina;
    always @(posedge clkb) if (rstb) doutb <= 0; else if (enb) doutb <= mem[addrb];
endmodule
