// tb_memddr.v - Icarus testbench for the REAL MemoryDDR (MigUiAdapter, mig_* FIFOs, RequestController,
// both Caches, PixelFeeder, GPU) with the MIG replaced by ui_mem_stub (models/mig_arty_a7_100.v).
//
// The CPU is replaced by two drivers that use the cache ports exactly like the MIPS pipeline: hold
// addr/re/we/din until stall is low, sample dout in that cycle. A shadow memory checks every load.
//   D-port: P1 fill 16 KB + read back, P2 random lw/sw/sh/sb over 64 KB (heavy cache conflicts),
//           P3 bit-27 alias + line-offset tests (0x18000040 vs 0x10000040, offset-16 write / offset-0 fill)
//   I-port: during P2, concurrent instruction fetches from a read-only 16 KB "code" area
//   PixelFeeder: +PF=1 selects frame 1 (0x10400000) at reset; P2/P3 start once it is on frame 1 (DDR reads)
// Plusargs: +OPS=n (P2 ops, default 3000) +PF=0/1 +SEED=n, and the stub's +RDY_PCT +INJECT ...
// Compile-time: -DPF_TESTPAT=n -DRD_CREDIT=0/1 (MemoryDDR parameters); -DLEGACY for the untouched eee4d5d RTL.
// Ends with "RESULT: PASS" or "RESULT: FAIL (...)".
`timescale 1ps/1ps
`ifndef PF_TESTPAT
 `define PF_TESTPAT 0
`endif
`ifndef RD_CREDIT
 `define RD_CREDIT 1
`endif
module tb_memddr;
    reg clk_cpu = 0, clk_pix = 0, clk_100 = 0, clk_200 = 0;
    always #10000 clk_cpu = ~clk_cpu;   // 50 MHz
    always #12500 clk_pix = ~clk_pix;   // 40 MHz
    always #5000  clk_100 = ~clk_100;
    always #2500  clk_200 = ~clk_200;

    integer ops, pf_en, seed;
    initial begin
        if (!$value$plusargs("OPS=%d", ops))  ops = 3000;
        if (!$value$plusargs("PF=%d", pf_en)) pf_en = 0;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    end

    // ---------------- resets, as in ArtyA7top: MIG sys_rst = lock; CPU waits for calibration
    reg locked = 0;
    initial #200000 locked = 1;
    wire init_done, clk_mig_ui, rst_mig_ui;
    reg [2:0] rc_cpu = 3'b111, rc_pix = 3'b111;
    always @(posedge clk_cpu) rc_cpu <= {rc_cpu[1:0], !(locked && init_done)};
    always @(posedge clk_pix) rc_pix <= {rc_pix[1:0], !(locked && init_done)};
    wire rst_cpu = rc_cpu[2], rst_pix = rc_pix[2];

    // ---------------- CPU-side ports
    reg  [31:0] d_addr = 0, d_din = 0, i_addr = 0;
    reg  [3:0]  d_we = 0;
    reg         d_re = 0, i_re = 0;
    wire [31:0] d_dout, i_dout;
    wire        d_stall, i_stall;
    reg         pf_vframe = 0; reg [31:0] pf_wframe = 0;
    wire        video_valid; wire [31:0] video; wire [15:0] pf_status, gp_status; wire [31:0] gp_rcode;
    wire        irq_pf, irq_gp, rdf_overflow; wire [3:0] dbg_a, dbg_d, dbg_i;

    // VGA-like consumer: 800 of every 1056 pixel clocks
    integer hcnt = 0;
    always @(posedge clk_pix) hcnt <= (hcnt == 1055) ? 0 : hcnt + 1;
    wire video_ready = !rst_pix && (hcnt < 800);

    wire [15:0] dq; wire [1:0] dqs_n, dqs_p; wire [13:0] a; wire [2:0] ba; wire [0:0] ckp, ckn, cke, csn, odt;
    wire [1:0] dm; wire ras, cas, we_n, rstn;

`ifdef LEGACY
    // Untouched eee4d5d MemoryDDR (64-bit 2:1 MIG, MIGAdapter): no new parameters/ports.
    assign rdf_overflow = 1'b0;
    defparam dut.pixfeed.COLT45_TESTPAT = `PF_TESTPAT;
    MemoryDDR #(.SCREEN_WIDTH(800), .SCREEN_HEIGHT(600)) dut (
`else
    MemoryDDR #(.SCREEN_WIDTH(800), .SCREEN_HEIGHT(600), .PF_TESTPAT(`PF_TESTPAT), .RD_CREDIT_EN(`RD_CREDIT)) dut (
`endif
        .clk_cpu(clk_cpu), .rst_cpu_mem(rst_cpu), .rst_cpu_bus(rst_cpu),
        .clk_mig_sys(clk_100), .rst_mig_sys_n(locked), .clk_mig_ref(clk_200),
        .clk_pix(clk_pix), .rst_pix(rst_pix),
        .init_done(init_done), .clk_mig_ui(clk_mig_ui), .rst_mig_ui(rst_mig_ui),
        .ddr3_dq(dq), .ddr3_dqs_n(dqs_n), .ddr3_dqs_p(dqs_p), .ddr3_addr(a), .ddr3_ba(ba),
        .ddr3_ras_n(ras), .ddr3_cas_n(cas), .ddr3_we_n(we_n), .ddr3_ck_p(ckp), .ddr3_ck_n(ckn),
        .ddr3_cke(cke), .ddr3_cs_n(csn), .ddr3_dm(dm), .ddr3_odt(odt), .ddr3_reset_n(rstn),
        .dcache_addr(d_addr), .icache_addr(i_addr), .dcache_we(d_we), .icache_we(4'b0000),
        .dcache_re(d_re), .icache_re(i_re), .dcache_din(d_din), .icache_din(32'd0),
        .dcache_dout(d_dout), .icache_dout(i_dout), .d_stall(d_stall), .i_stall(i_stall),
        .DBG_dcache(dbg_d), .DBG_icache(dbg_i), .DBG_adapt(dbg_a),
`ifndef LEGACY
        .DBG_rdf_overflow(rdf_overflow),
`endif
        .video_ready(video_ready), .video_valid(video_valid), .video(video),
        .pf_vframe(pf_vframe), .gp_vcode(1'b0), .gp_vframe(1'b0),
        .pf_wframe(pf_wframe), .gp_wcode(32'd0), .gp_wframe(32'd0), .gp_rcode(gp_rcode),
        .pf_status(pf_status), .gp_status(gp_status), .irq_pf_frame(irq_pf), .irq_gp_done(irq_gp),
        .DBG_no_cache(1'b0)
    );

    // ---------------- shadow memory: W0 = 0x1000_0000 + 256 KB, WA = 0x1800_0000 + 4 KB
    reg [31:0] sh0 [0:65535];
    reg [31:0] sha [0:1023];
    integer k;
    initial begin for (k = 0; k < 65536; k = k + 1) sh0[k] = 32'hxxxxxxxx; for (k = 0; k < 1024; k = k + 1) sha[k] = 32'hxxxxxxxx; end
    function [31:0] sh_get(input [31:0] ad);
        sh_get = (ad[31:28] == 4'h1 && ad[27:18] == 0) ? sh0[ad[17:2]] :
                 (ad[31:12] == 20'h18000) ? sha[ad[11:2]] : 32'hxxxxxxxx;
    endfunction
    task sh_put(input [31:0] ad, input [31:0] d, input [3:0] we);
        reg [31:0] o; integer b;
        begin
            o = sh_get(ad);
            for (b = 0; b < 4; b = b + 1) if (we[b]) o[8*b +: 8] = d[8*b +: 8];
            if (ad[31:28] == 4'h1 && ad[27:18] == 0) sh0[ad[17:2]] = o;
            else if (ad[31:12] == 20'h18000) sha[ad[11:2]] = o;
        end
    endtask

    integer errors = 0, checks = 0, timeouts = 0;
    task check(input [8*8-1:0] who, input [31:0] ad, input [31:0] got);
        reg [31:0] exp;
        begin
            exp = sh_get(ad); checks = checks + 1;
            // per byte: bytes never written by the tb (x in the shadow) are don't-care
            if ((exp[31:24] !== 8'hxx && got[31:24] !== exp[31:24]) || (exp[23:16] !== 8'hxx && got[23:16] !== exp[23:16]) ||
                (exp[15: 8] !== 8'hxx && got[15: 8] !== exp[15: 8]) || (exp[ 7: 0] !== 8'hxx && got[ 7: 0] !== exp[ 7: 0])) begin
                errors = errors + 1;
                if (errors <= 12) $display("[%0t] MISMATCH %0s lw %08h: got %08h expected %08h", $time, who, ad, got, exp);
            end
        end
    endtask

    // D-port access, MIPS style: present request, hold until a cycle with !stall, sample dout there.
    task d_access(input [31:0] ad, input [3:0] we, input [31:0] din, output [31:0] dout);
        integer n;
        begin
            @(negedge clk_cpu); d_addr = ad; d_we = we; d_re = (we == 0); d_din = din;
            n = 0;
            @(posedge clk_cpu); #1;
            while (d_stall) begin
                @(posedge clk_cpu); #1; n = n + 1;
                if (n > 50000) begin timeouts = timeouts + 1; $display("[%0t] D-port STALL TIMEOUT at %08h (dcache state %h, adapter %h)", $time, ad, dbg_d, dbg_a); disable d_access; end
            end
            dout = d_dout;
            d_we = 0; d_re = 0;
        end
    endtask
    task dsw(input [31:0] ad, input [31:0] d, input [3:0] we); reg [31:0] x; begin d_access(ad, we, d, x); sh_put(ad, d, we); end endtask
    task dlw(input [31:0] ad); reg [31:0] x; begin d_access(ad, 4'b0000, 0, x); check("D", ad, x); end endtask

    task i_fetch(input [31:0] ad);
        integer n; reg [31:0] x;
        begin
            @(negedge clk_cpu); i_addr = ad; i_re = 1;
            n = 0; @(posedge clk_cpu); #1;
            while (i_stall) begin
                @(posedge clk_cpu); #1; n = n + 1;
                if (n > 50000) begin timeouts = timeouts + 1; $display("[%0t] I-port STALL TIMEOUT at %08h", $time, ad); disable i_fetch; end
            end
            x = i_dout; i_re = 0;
            check("I", ad, x);
        end
    endtask

    // ---------------- monitors
    integer rdf_ovf = 0, pix_ovf = 0, video_faults = 0;
    always @(posedge clk_mig_ui) if (dut.fifo_rdf_wr_en && dut.fifo_rdf_full) rdf_ovf = rdf_ovf + 1;
`ifdef LEGACY
    always @(posedge clk_cpu) if (dut.pixfeed.ffwr_valid && dut.pixfeed.ffwr_full) pix_ovf = pix_ovf + 1;
`else
    always @(posedge clk_cpu) if (dut.pixfeed.ffwr_drop) pix_ovf = pix_ovf + 1;  // beat lost (write is gated)
`endif
    reg seen_vfault = 0;
    always @(posedge clk_cpu) if (pf_status[15] && !seen_vfault) begin seen_vfault = 1; $display("[%0t] PixelFeeder video_fault (pixel FIFO under/overflow)", $time); end
    integer pf_reads = 0;
    always @(posedge clk_cpu) if (dut.pixf_raf_wren && !dut.pixf_raf_full) pf_reads = pf_reads + 1;

    // ---------------- stimulus
    integer i, r, w, op; reg [31:0] ad, dat; reg [3:0] we; reg d_done = 0;
    initial begin
        r = $random(seed);
        wait (!rst_cpu); repeat (20) @(posedge clk_cpu);
        $display("[%0t] reset released (init_done), PF=%0d PF_TESTPAT=%0d RD_CREDIT=%0d OPS=%0d", $time, pf_en, `PF_TESTPAT, `RD_CREDIT, ops);
        if (pf_en) begin @(negedge clk_cpu); pf_wframe = 32'h1040_0000; pf_vframe = 1; @(negedge clk_cpu); pf_vframe = 0; end
        // P1: fill 0x1000_0000..+16 KB (data) and 0x1000_8000..+16 KB (code), then read back data
        for (i = 0; i < 4096; i = i + 1) dsw(32'h1000_0000 + 4*i, 32'hA500_0000 ^ (i * 32'h9E37_79B9), 4'b1111);
        for (i = 0; i < 4096; i = i + 1) dsw(32'h1000_8000 + 4*i, 32'h0C0D_E000 ^ (i * 32'h85EB_CA6B), 4'b1111);
        for (i = 0; i < 4096; i = i + 1) dlw(32'h1000_0000 + 4*i);
        $display("[%0t] P1 done: %0d checks, %0d errors", $time, checks, errors);
        if (pf_en) begin  // frame 1 takes effect at the next frame boundary (~16.6 ms of video)
            i = 0; while (pf_status[13:8] == 0 && i < 1200000) begin @(posedge clk_cpu); i = i + 1; end
            $display("[%0t] PixelFeeder now on frame %0d (DDR 0x%08h)", $time, pf_status[13:8], {4'h1, pf_status[13:8], 22'h0});
        end
        // P2: random D-port ops over 64 KB; I-port fetches run concurrently (fork below)
        fork
            begin
                for (i = 0; i < ops; i = i + 1) begin
                    op = $random % 8; if (op < 0) op = -op;
                    w = $random % 16384; if (w < 0) w = -w;
                    ad = (op == 7) ? (32'h1800_0000 + 4*(w % 1024)) : (32'h1000_0000 + 4*(w % 8192) + ((w & 1) ? 32'h4000 : 0));
                    if (ad[15:14] == 2'b10) ad[15:14] = 2'b01;     // never write the code area
                    dat = $random;
                    case (op % 4)
                        0, 1: dlw(ad);
                        2:    dsw(ad, dat, 4'b1111);
                        3:    begin we = 4'b0001 << ($random & 3); if ($random & 1) we = (dat[0] ? 4'b0011 : 4'b1100); dsw(ad, dat, we); end
                    endcase
                end
                d_done = 1;
            end
            begin
                while (!d_done) begin
                    w = $random % 4096; if (w < 0) w = -w;
                    for (k = 0; k < 8 && !d_done; k = k + 1) i_fetch(32'h1000_8000 + 4*((w + k) % 4096));
                end
            end
        join
        $display("[%0t] P2 done: %0d checks, %0d errors", $time, checks, errors);
        // P3: rank-bit alias and line-offset tests (cache is 8 KB direct mapped: +8 KB evicts)
        dsw(32'h1800_0040, 32'h1800_0040, 4'b1111);
        dsw(32'h1000_0040, 32'h1000_0040, 4'b1111);
        dlw(32'h1000_2040); dlw(32'h1800_0040); dlw(32'h1000_0040);
        dsw(32'h1000_1014, 32'hC0FF_EE14, 4'b1111);            // word at line offset 20
        dlw(32'h1000_3000);                                    // evict that line
        dlw(32'h1000_1000); dlw(32'h1000_1014);                // miss at offset 0, then hit at 20
        $display("[%0t] P3 done: %0d checks, %0d errors", $time, checks, errors);
        repeat (2000) @(posedge clk_cpu);
        $display("SUMMARY: checks=%0d mismatches=%0d stall_timeouts=%0d stub_protocol_errors=%0d", checks, errors, timeouts, dut.u_mig_arty_a7_100.protocol_errors);
        $display("SUMMARY: mig_rdf_overflows=%0d adapter_overflow_flag=%0d pixel_fifo_overflows=%0d pf_reads=%0d video_fault=%0d pf_status=%04h",
                 rdf_ovf, rdf_overflow, pix_ovf, pf_reads, pf_status[15], pf_status);
        if (errors == 0 && timeouts == 0 && dut.u_mig_arty_a7_100.protocol_errors == 0 && rdf_ovf == 0 && pix_ovf == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL (mismatches=%0d timeouts=%0d protocol=%0d rdf_overflow=%0d pixel_overflow=%0d)",
                     errors, timeouts, dut.u_mig_arty_a7_100.protocol_errors, rdf_ovf, pix_ovf);
        $finish;
    end
    initial begin #400_000_000_000; $display("RESULT: FAIL (global timeout)"); $finish; end
endmodule
