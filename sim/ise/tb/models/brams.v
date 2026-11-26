`timescale 1ns/1ps
// Behavioral models of proj150's block-RAM IP as MemBank uses it (ip/bios_mem.tcl, isr_mem.tcl,
// dmem_blk_ram.tcl, imem_blk_ram.tcl): 32 x 4096, synchronous read, byte writes, port B = instruction
// fetch. Initial contents from <name>.mif in the run directory (CoreGen .mif: one 32-character
// binary word per line), staged by scripts/build-sw.sh from sw/*.coe or a program built for the test.
module sim_bram_tdp #(parameter MIF = "none.mif", parameter WORDS = 4096) (
    input clka, ena, input [3:0] wea, input [11:0] addra, input [31:0] dina, output reg [31:0] douta,
    input clkb, enb, input [3:0] web, input [11:0] addrb, input [31:0] dinb, output reg [31:0] doutb
);
    reg [31:0] mem [0:WORDS-1];
    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'd0;
        $readmemb(MIF, mem);
    end
    always @(posedge clka) if (ena) begin
        for (i = 0; i < 4; i = i + 1) if (wea[i]) mem[addra][8*i +: 8] <= dina[8*i +: 8];
        douta <= (|wea) ? {wea[3] ? dina[31:24] : mem[addra][31:24], wea[2] ? dina[23:16] : mem[addra][23:16],
                           wea[1] ? dina[15: 8] : mem[addra][15: 8], wea[0] ? dina[ 7: 0] : mem[addra][ 7: 0]}
                        : mem[addra];   // WRITE_FIRST on port A
    end
    always @(posedge clkb) if (enb) begin
        for (i = 0; i < 4; i = i + 1) if (web[i]) mem[addrb][8*i +: 8] <= dinb[8*i +: 8];
        doutb <= mem[addrb];            // READ_FIRST on port B
    end
endmodule

module bios_mem (input clka, ena, input [11:0] addra, output [31:0] douta,
                 input clkb, enb, input [11:0] addrb, output [31:0] doutb);
    sim_bram_tdp #(.MIF("bios_mem.mif")) m (.clka(clka), .ena(ena), .wea(4'b0), .addra(addra), .dina(32'b0), .douta(douta),
                                           .clkb(clkb), .enb(enb), .web(4'b0), .addrb(addrb), .dinb(32'b0), .doutb(doutb));
endmodule
`define SIM_BRAM_TDP(NAME) \
module NAME (input clka, ena, input [3:0] wea, input [11:0] addra, input [31:0] dina, output [31:0] douta, \
             input clkb, enb, input [3:0] web, input [11:0] addrb, input [31:0] dinb, output [31:0] doutb); \
    sim_bram_tdp #(.MIF(`"NAME.mif`")) m (.clka(clka), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(douta), \
                                      .clkb(clkb), .enb(enb), .web(web), .addrb(addrb), .dinb(dinb), .doutb(doutb)); \
endmodule
`SIM_BRAM_TDP(isr_mem)
`SIM_BRAM_TDP(dmem_blk_ram)
`SIM_BRAM_TDP(imem_blk_ram)
