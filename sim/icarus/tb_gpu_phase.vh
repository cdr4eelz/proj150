// tb_gpu_phase.vh - P5: drive the real GraphicsProcessor (FILL / LINE / ELIP) end to end through
// MemoryDDR: GPCode is written with D-port stores (write-through), the GP fetches it over the gcmd
// path (one word per GOP/colour, then ONE word per point: x[25:16] y[9:0]), the ScanLineRunner writes pixels over the bpas path, and pixels are read back with D-port
// loads. Included inside tb_memddr (module scope). Enabled with +GP=1.
//   frame 2: FILL                       frame 3: FILL + 2 LINEs
//   frame 4: FILL + 5 ELIPs             frame 5: one screen-size ELIP (no FILL: stays DEADBEEF) (a=399 b=299)
// ELIP expected pixels come from gp_elip_model (the ISE swelip algorithm in 64-bit arithmetic with
// an analytic |b^2x^2 + a^2y^2 - a^2b^2| sanity check); every expected pixel is read back and
// whole sample rows are read back to catch stray pixels.
integer gp_en, gp_tmo;
initial begin
    if (!$value$plusargs("GP=%d", gp_en)) gp_en = 0;
    if (!$value$plusargs("GP_TMO=%d", gp_tmo)) gp_tmo = 3000000;   // cycles a GPCode run may take
end

localparam [31:0] GPC_BASE = 32'h1010_0000;
integer gp_errors = 0, gp_checks = 0, gp_timeouts = 0;

// ---- expected image of the frame under test: bit 24 = "defined", [23:0] = colour
reg [31:0] gx [0:479999];
integer    gx_n;
task gx_clear(input [31:0] bg);
    integer q;
    begin for (q = 0; q < 480000; q = q + 1) gx[q] = bg; end
endtask
task gx_plot(input integer px, input integer py, input [23:0] c);
    begin
        if (px >= 0 && px < 800 && py >= 0 && py < 600) gx[py*800 + px] = {8'h00, c};
        else begin gp_errors = gp_errors + 1; $display("GP MODEL: plot out of range %0d,%0d", px, py); end
    end
endtask

// ---- ellipse reference model (outline only, 4-way symmetric), returns number of pixel plots
integer model_plots, model_steps, model_badfit;
task gx_plot4(input integer xc, input integer yc, input integer x, input integer y, input [23:0] c,
              input signed [63:0] AA, input signed [63:0] BB);
    reg signed [63:0] f, mag; real g;
    begin
        gx_plot(xc + x, yc + y, c); gx_plot(xc - x, yc + y, c);
        gx_plot(xc + x, yc - y, c); gx_plot(xc - x, yc - y, c);
        model_plots = model_plots + 1;
        // analytic fit: |f| <= 2 * |grad f| / 2 ... (pixel centre within ~1 px of the true curve)
        f = BB*x*x + AA*y*y - AA*BB;
        g = $sqrt($itor(BB*BB)*x*x + $itor(AA*AA)*y*y);
        if ((f < 0 ? -f : f) > $rtoi(2.0*g) + 1) model_badfit = model_badfit + 1;
    end
endtask
task gp_elip_model(input integer xc, input integer yc, input integer a, input integer b, input [23:0] c);
    reg signed [63:0] AA, BB, AABB, AAy, BBx, BB2xp3, BB2xp2, dd, stopper;
    integer x, y;
    begin
        x = 0; y = b; AA = a*a; BB = b*b; AABB = AA*BB;
        AAy = AA*b; BBx = 0; BB2xp3 = 3*BB; stopper = (AA >>> 1) + BB;
        dd = BB - AA*b + (AA >>> 2);
        gx_plot4(xc, yc, x, y, c, AA, BB);
        while (y > 0 && x <= a && (AAy - BBx) > stopper) begin
            if (dd >= 0) begin dd = dd + 2*AA - 2*AAy; y = y - 1; AAy = AAy - AA; end
            dd = dd + BB2xp3; x = x + 1; BBx = BBx + BB; BB2xp3 = BB2xp3 + 2*BB;
            gx_plot4(xc, yc, x, y, c, AA, BB);
        end
        BB2xp2 = BB2xp3 - BB;
        dd = BB*(x*x + x) + (BB >>> 2) + AA*(y-1)*(y-1) - AABB;
        while (y > 0) begin
            if (dd < 0) begin dd = dd + BB2xp2; x = x + 1; BB2xp2 = BB2xp2 + 2*BB; end
            dd = dd + 3*AA - 2*AAy; y = y - 1; AAy = AAy - AA;
            gx_plot4(xc, yc, x, y, c, AA, BB);
        end
    end
endtask

// ---- GPCode writer
integer gpc_n;
task gpc_w(input [31:0] w);
    begin dsw(GPC_BASE + 4*gpc_n, w, 4'b1111); gpc_n = gpc_n + 1; end
endtask
task gpc_fill(input [23:0] c);  begin gpc_w({8'h01, c}); end endtask
task gpc_line(input [23:0] c, input integer x0, input integer y0, input integer x1, input integer y1);
    begin gpc_w({8'h02, c}); gpc_w((x0 << 16) | y0); gpc_w((x1 << 16) | y1); end
endtask
task gpc_elip(input [23:0] c, input integer xc, input integer yc, input integer a, input integer b);
    begin gpc_w({8'h03, c}); gpc_w((xc << 16) | yc); gpc_w((a << 16) | b); end
endtask
task gpc_end; begin gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); gpc_w(32'h0); end endtask

// ---- run the GPCode on a frame; ok=1 when the GP returned to ready (status[0]) and elip_ready (status[3])
integer gp_cycles;
task gp_run(input [5:0] frame, output ok);
    integer n;
    begin
        ok = 0;
        repeat (3000) @(posedge clk_cpu);   // let the write-through stores of the code drain
        n = 0; while (!gp_status[0] && n < 100000) begin @(posedge clk_cpu); n = n + 1; end
        @(negedge clk_cpu); gp_wframe_r = {4'h1, frame, 22'd0}; gp_wcode_r = GPC_BASE; gp_vcode_r = 1;
        @(negedge clk_cpu); gp_vcode_r = 0;
        n = 0;
        while (gp_status[0] && n < 100) begin @(posedge clk_cpu); n = n + 1; end    // leaves ready
        n = 0;
        while (!gp_status[0] && n < gp_tmo) begin @(posedge clk_cpu); n = n + 1; end
        gp_cycles = n;
        if (!gp_status[0]) begin
            gp_timeouts = gp_timeouts + 1;
            $display("[%0t] GP TIMEOUT frame %0d: GP not ready after %0d cycles (gp_status=%04h gp_rcode=%08h)",
                     $time, frame, n, gp_status, gp_rcode);
        end else begin
            ok = 1;
            if (!gp_status[3] || !gp_status[2] || !gp_status[1] || gp_status[15]) begin
                gp_errors = gp_errors + 1; ok = 0;
                $display("[%0t] GP BAD STATUS frame %0d: gp_status=%04h", $time, frame, gp_status);
            end
        end
        repeat (4000) @(posedge clk_cpu);   // SLR / bpas write drain
    end
endtask

// ---- pixel read-back checks
task gp_px(input [5:0] frame, input integer x, input integer y);
    reg [31:0] got, e;
    begin
        d_access(32'h1000_0000 | (frame << 22) | (y << 12) | (x << 2), 4'b0000, 0, got);
        e = gx[y*800 + x]; gp_checks = gp_checks + 1;
        if (got !== e) begin
            gp_errors = gp_errors + 1;
            if (gp_errors <= 16) $display("[%0t] GP MISMATCH frame %0d (%0d,%0d): got %08h expected %08h", $time, frame, x, y, got, e);
        end
    end
endtask
task gp_row(input [5:0] frame, input integer y);
    integer x; begin for (x = 0; x < 800; x = x + 1) gp_px(frame, x, y); end
endtask
// read back every pixel the model painted with a non-background colour in a bounding box
task gp_box(input [5:0] frame, input integer x0, input integer y0, input integer x1, input integer y1, input [31:0] bg);
    integer x, y;
    begin
        for (y = y0; y <= y1; y = y + 1) for (x = x0; x <= x1; x = x + 1)
            if (gx[y*800 + x] !== bg) gp_px(frame, x, y);
    end
endtask

task gp_phase;
    reg ok; integer i, x, y, ycalc;
    begin
        $display("[%0t] P5: GPU FILL / LINE / ELIP end to end", $time);
        // ---------------- frame 2: FILL only
        gpc_n = 0; gpc_fill(24'h112233); gpc_end;
        gp_run(6'd2, ok);
        gx_clear(32'h00112233);
        if (ok) begin
            gp_px(2, 0, 0); gp_px(2, 799, 599); gp_px(2, 400, 300); gp_px(2, 7, 1); gp_px(2, 8, 1); gp_px(2, 799, 0); gp_px(2, 0, 599);
            gp_row(2, 0); gp_row(2, 599);
            $display("[%0t] P5 FILL: cycles=%0d checks=%0d errors=%0d", $time, gp_cycles, gp_checks, gp_errors);
        end
        // ---------------- frame 3: FILL + LINEs
        gpc_n = 0; gpc_fill(24'h102030);
        gpc_line(24'hff0000, 0, 0, 799, 599);
        gpc_line(24'h00ffff, 100, 500, 700, 50);
        gpc_end;
        gp_run(6'd3, ok);
        if (ok) begin
            gx_clear(32'h00102030);
            // endpoints exact
            gx_plot(0, 0, 24'hff0000); gx_plot(799, 599, 24'hff0000);
            gx_plot(100, 500, 24'h00ffff); gx_plot(700, 50, 24'h00ffff);
            gp_px(3, 0, 0); gp_px(3, 799, 599); gp_px(3, 100, 500); gp_px(3, 700, 50);
            // along each line: at sampled x the line colour must be present within +-1 row
            gp_line_samples(3);
            gp_px(3, 5, 300); gp_px(3, 799, 0); gp_px(3, 0, 599); gp_px(3, 400, 20);
            $display("[%0t] P5 LINE: cycles=%0d checks=%0d errors=%0d", $time, gp_cycles, gp_checks, gp_errors);
        end
        // ---------------- frame 4: FILL + 5 ELIPs
        model_plots = 0; model_badfit = 0;
        gx_clear(32'h00001020);
        gp_elip_model(400, 300, 200, 150, 24'h00ff00);
        gp_elip_model(100,  80,  30,  60, 24'hffff00);
        gp_elip_model(700, 520,  60,  40, 24'hff00ff);
        gp_elip_model(600, 100,  50,  50, 24'h00ffff);
        gp_elip_model(300, 550,   3,   2, 24'hffffff);
        $display("[%0t] P5 ELIP model: frame-4 plots=%0d analytic_misfits=%0d", $time, model_plots, model_badfit);
        if (model_badfit != 0) gp_errors = gp_errors + 1;
        gpc_n = 0; gpc_fill(24'h001020);
        gpc_elip(24'h00ff00, 400, 300, 200, 150);
        gpc_elip(24'hffff00, 100,  80,  30,  60);
        gpc_elip(24'hff00ff, 700, 520,  60,  40);
        gpc_elip(24'h00ffff, 600, 100,  50,  50);
        gpc_elip(24'hffffff, 300, 550,   3,   2);
        gpc_end;
        gp_run(6'd4, ok);
        if (ok) begin
            $display("[%0t] P5 ELIP frame 4 finished in %0d cycles", $time, gp_cycles);
            gp_box(4, 195, 145, 605, 455, 32'h00001020);
            gp_box(4,  65,  15, 135, 145, 32'h00001020);
            gp_box(4, 635, 475, 765, 565, 32'h00001020);
            gp_box(4, 545,  45, 655, 155, 32'h00001020);
            gp_box(4, 295, 545, 305, 555, 32'h00001020);
            for (i = 0; i < 12; i = i + 1) begin y = (i*53) % 600; gp_row(4, y); end
            gp_row(4, 150); gp_row(4, 300); gp_row(4, 449); gp_row(4, 450); gp_row(4, 20); gp_row(4, 551);
            $display("[%0t] P5 ELIP frame 4: checks=%0d errors=%0d", $time, gp_checks, gp_errors);
        end
        // ---------------- frame 5: one screen-size ELIP (AABB overflows 32 bits; rows/cols touch the edges)
        model_plots = 0; model_badfit = 0;
        gx_clear(32'hDEADBEEF);   // no FILL: unwritten memory reads as the stub's DEADBEEF
        gp_elip_model(400, 300, 399, 299, 24'hff8000);
        $display("[%0t] P5 ELIP model: frame-5 plots=%0d analytic_misfits=%0d", $time, model_plots, model_badfit);
        if (model_badfit != 0) gp_errors = gp_errors + 1;
        gpc_n = 0; gpc_elip(24'hff8000, 400, 300, 399, 299); gpc_end;
        gp_run(6'd5, ok);
        if (ok) begin
            $display("[%0t] P5 ELIP frame 5 finished in %0d cycles", $time, gp_cycles);
            gp_box(5, 0, 0, 799, 599, 32'hDEADBEEF);
            for (i = 0; i < 6; i = i + 1) gp_row(5, i*111);
            $display("[%0t] P5 ELIP frame 5: checks=%0d errors=%0d", $time, gp_checks, gp_errors);
        end
        $display("[%0t] P5 done: gp_checks=%0d gp_errors=%0d gp_timeouts=%0d", $time, gp_checks, gp_errors, gp_timeouts);
    end
endtask

// colour of the line near (x, yline): present on the expected row +-1
task gp_line_samples(input [5:0] frame);
    integer i, x, y, yy; reg [31:0] got; reg hit;
    begin
        for (i = 0; i <= 40; i = i + 1) begin
            x = (i * 799) / 40; y = (x * 599 + 399) / 799; hit = 0;
            for (yy = y - 1; yy <= y + 1; yy = yy + 1) begin
                d_access(32'h1000_0000 | (frame << 22) | (yy << 12) | (x << 2), 4'b0000, 0, got);
                if (yy >= 0 && yy < 600 && got === 32'h00ff0000) hit = 1;
            end
            gp_checks = gp_checks + 1;
            if (!hit) begin gp_errors = gp_errors + 1; if (gp_errors <= 16) $display("GP LINE MISSING near (%0d,%0d)", x, y); end
        end
        for (i = 0; i <= 40; i = i + 1) begin
            x = 100 + (i * 600) / 40; y = 500 - ((x - 100) * 450 + 300) / 600; hit = 0;
            for (yy = y - 1; yy <= y + 1; yy = yy + 1) begin
                d_access(32'h1000_0000 | (frame << 22) | (yy << 12) | (x << 2), 4'b0000, 0, got);
                if (yy >= 0 && yy < 600 && got === 32'h0000ffff) hit = 1;
            end
            gp_checks = gp_checks + 1;
            if (!hit) begin gp_errors = gp_errors + 1; if (gp_errors <= 16) $display("GP LINE2 MISSING near (%0d,%0d)", x, y); end
        end
    end
endtask
