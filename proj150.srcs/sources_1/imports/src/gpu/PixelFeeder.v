/* This module keeps a FIFO filled that then outputs to the DVI module. */
`default_nettype none

`include "gpcommands.vh"

module PixelFeeder #(
    parameter DVI_CLOCK_HZ = 40_000_000,
    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600,
//TODO:Unimplemented LITTLEWORDIAN...
    parameter LITTLEWORDIAN = 1,
    parameter COLT45_TESTPAT = 0 // 1..3 are non-DDR test feeds of various sorts
)(
//System:
    input  wire         cpu_clk_g,
    input  wire         cpu_rst_g,
    input  wire         dvi_clk_g,
    input  wire         dvi_rst_g,
//DDR FIFOs (read-only) @cpu_clk_g:
    input  wire         raf_full,
    output wire         raf_wren,
    output wire[ 27:0]  raf_addr,
    output wire         rdf_rden,
    input  wire         rdf_wren,
    input  wire[127:0]  rdf_data,
// DVI driver @dvi_clk_g:
    input  wire         video_ready,
    output wire         video_valid,
    output wire[ 31:0]  video, //[23:0]
// FRAME control <=> CPU @cpu_clk_g:
    input  wire         pf_vframe,  //Signal new pf_wframe is to be captured this clock cycle
    input  wire[ 31:0]  pf_wframe,  //Address or Frame# for base of NEXT frame once this one is done
    output wire[ 15:0]  pf_status,  //Composite status ("ready" signal not present/used)
    output wire         irq_frame   //1-cycle pulse after frame transition (except startup frame)
);

    localparam X_PIX_PER_CHUNK = 8; //Number of pixels (32-bit words) to advance per DDR request
    //TODO: Compute other localparams based on this, like "framebits" size and "last_x" condition!

// Use FIFO's separate "busy" signals and register the "combinational" reset signal
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE" *)
    reg  cpu_rst_r, dvi_rst_r; // Release synchronously to each clock
    wire ffwr_rst_busy, ffrd_rst_busy; // Driven by FIFO
    always @(posedge cpu_clk_g) begin
        cpu_rst_r <= cpu_rst_g || ffwr_rst_busy;
    end
    always @(posedge dvi_clk_g) begin
        dvi_rst_r <= dvi_rst_g || ffrd_rst_busy;
    end

//***CLOCK CROSSING STRATEGY***
    // 1-request to wf => 2-responses on rdf => 8-pixels out of fifo (all 256-bits).
    //    Don't care about individual pixels in PixelFeeder!
    // pixel_fifo is 128-bit write (2K depth) and 32-bit read (8K depth).
    //    Forced to grab rdf output or lose it, no back-pressure opportunity there.
    // pixel_fifo available space tracked by "prog_full" signal (in write clock domain).
    // DVI side just reads from FIFO and outputs, with no knowledge of raf/rdf
    //NOTE: There are some cross-clock signals simply for slow-speed status reporting to CPPU...
    //      Need to ensure those use proper synchronizers and relaxed timing constraints.
// Cross-clock signal & acknowledge (using 4-cycle ack technique from Fall-13 for chunks)???

// DVI-Clocked region (dvi_clk_g)

/* ABANDONED VIDEO GENERATION CODE (LEFT COMMENTED HERE TEMPORARILY). Only feeder_running was in use elsewhere.
     This code makes me wonder if I should generate the VGA signals directly from PixelFeeder instead of
     passing video to VGAFramer. Of course, there are two sides to things, the CPU domain fetching 256-bit chunks
     from the DDR, versus the "DVI" domain outputting 32-bit pixels to the VGA PMOD. Filling the FIFO up to a
     safe point SHOULD ensure that the VGA output doesn't miss pixels, but maybe that is inevitable. I could
     use the upper byte of the 32-bit "video" output as a "control" channel to the VGAFramer, telling it when
     to re-sync with our delayed signal (ouput from the FIFO). For example, I could set the upper byte to 0xFF
     for the first pixel of each line, or more likely, for the top-left pixel of the screen???

    reg  feeder_running;
    reg  [31:0] curCOL, curROW, curFRAME;
    wire video_adv = (video_valid && video_ready); //reset will trump this
    wire rollCOL = (curCOL >= SCREEN_WIDTH  - 1);//TODO: Could use fast-counter/pixelrange?
    wire rollROW = (curROW >= SCREEN_HEIGHT - 1);

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin // Use synchronized reset
            {curCOL, curROW, curFRAME} <= 0;
            feeder_running <= 1'b0;
        end else begin
            feeder_running <= 1'b1;
            curCOL <= curCOL;
            curROW <= curROW;
            curFRAME <= curFRAME;
            if (video_adv) begin // They got a pixel, move on!
                case ({rollROW, rollCOL}) // Manage our col/row/frame/scene business
                    (2'b11): begin
                        curFRAME <= curFRAME + 1;
                        {curCOL, curROW} <= {32'd0, 32'd0};
                    end
                    (2'b01): begin
                        curCOL  <= 32'd0;
                        curROW  <= curROW + 1;
                    end
                    // 2'b10 just means we're ON last row but not yet at end of columns
                    default: curCOL <= curCOL + 1;
                endcase
            end
        end
    end
    wire fakeALL = (curCOL == curROW);
    wire [  7:0] fakeR = (fakeALL || (curCOL % 80 == 0) || (curCOL % 80 == 1) || (curCOL % 80 == 2)) ? 8'hFF : 8'h00;
    wire [  7:0] fakeG = (fakeALL || (curCOL % 80 == 2) || (curCOL % 80 == 3) || (curCOL % 80 == 4)) ? 8'hFF : 8'h00;
    wire [  7:0] fakeB = (fakeALL || (curCOL % 77 == 0) || (curCOL % 77 == 1) || (curCOL % 77 == 2)) ? 8'hFF : 8'h00;
*/

//TODO: *** Move all FIFO-related signals ("ffwr_" and "ffrd_") into the generate block where FIFO is!
    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is reasonably full (custom "prog_full"). Other "fullness" signals are debug.
    wire [127:0] ffwr_din;
    wire         ffwr_valid, ffwr_full, ffwr_almost_full, ffwr_prog_full;
    wire [ 31:0] ffrd_dout; //TODO: Register "ffrd_dout" in case it is not immediatly used?
    wire         ffrd_empty, ffrd_valid;

    //Additional signals for debugging
    wire ffwr_ack, ffwr_overflow, ffrd_underflow;

generate
if ((COLT45_TESTPAT == 0) || (COLT45_TESTPAT == 1)) begin:_WITH_FIFO_

//TODO:Insert DDRStage before pixel_fifo to allow LITTLEWORDIAN flip
//NOTE: Renamed FIFO signals to distinguish in/out, rd/wr, & clarify clock domain
    wire ffrd_prog_empty, ffrd_ready;
    pixel_fifo pf_fifo (
        .rst(cpu_rst_g), //FIFO does internal clock syncs (see "busy" signals)
        //WRITE: CPU clock domain
        .wr_clk         (cpu_clk_g),        // input
        .full           (ffwr_full),        // output
        .almost_full    (ffwr_almost_full), // output
        .prog_full      (ffwr_prog_full),   // output
        .wr_en          (ffwr_valid),       // input               rdf_wren
        .din            (ffwr_din),         // input wire [127:0]  rdf_data
        .wr_rst_busy    (ffwr_rst_busy),    // output

        //READ: DVI clock domain
        .rd_clk         (dvi_clk_g),        // input
        .empty          (ffrd_empty),       // output
        .prog_empty     (ffrd_prog_empty),  // output  NOTE: Custom "prog_empty" is set to near full!
        .rd_en          (ffrd_ready),       // input   WAS: video_ready
        .valid          (ffrd_valid),       // output  TODO: Use "valid" signal for diagnostics (set a fault)
        .dout           (ffrd_dout),        // output  NOTE: Ignoring "valid" signal (allow underflow???)
        .rd_rst_busy    (ffrd_rst_busy),    // output

        //EXTRA: Mostly for debug
        .wr_ack         (ffwr_ack),         // output
        .overflow       (ffwr_overflow),    // output
        .underflow      (ffrd_underflow)    // output
    );

    // Wait for FIFO to be full enough before we start offering video to be read from it
    reg fifo_running = 0;
    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin
            fifo_running <= 0; // Only reset can clear FIFO running mode
        end else begin
            fifo_running <= fifo_running; // Default is to hold current value
            if (!ffrd_prog_empty) begin //NOTE: !ffrd_prog_empty set to desired full target
                fifo_running <= 1; // Start offering video once FIFO is "full enough"
            end
        end
    end

    // Block both ready/valid signals to postpone video xfer until FIFO is full enough
    assign ffrd_ready = fifo_running && video_ready; //TODO: Use ffrd_ready to detect xfer
    assign video_valid = fifo_running && ffrd_valid;
    
end:_WITH_FIFO_
endgenerate


//FAULT and ACTVE detection
//TODO: Use REAL synchronizers for cross-clock signals & make faults more useful!
    reg  video_fault_dvi, video_fault_cpu, video_fault, video_active;

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  video_active_clkCPU, video_fault_clkCPU;

    (* EQUIVALENT_REGISTER_REMOVAL="OFF" *)
    reg  [7:0] video_active_dvi, video_active_cpu;

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin //WAS: dvi_rst_g
            video_fault_dvi <= 1'b0;
        end else if (video_ready && video_valid && ffrd_empty) begin
            video_fault_dvi <= 1'b1; //DVI-side fault if we run out of pixels
        end else if (ffrd_underflow || (video_ready && ffrd_empty)) begin
            //TODO: Could this just be "underflow" flag?
            video_fault_dvi <= 1'b1;
        end else begin
            video_fault_dvi <= video_fault_dvi;
        end

        video_active_dvi[7:0] <= {video_active_dvi[6:0], (video_ready && video_valid)};
    end

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_g) begin
            video_fault_cpu <= 1'b0;
        end else if (ffwr_valid && ffwr_full) begin //TODO: Could this just be "overflow" flag?
            video_fault_cpu <= 1'b1; //TODO: Distinguish different faults
        end

        //TODO: This whole "shift register" business is a hacky sub for sync...
        video_active_clkCPU   <= |video_active_dvi;
        video_active_cpu[7:0] <= {video_active_cpu[6:0], video_active_clkCPU};
        video_active          <= |video_active_cpu || video_active_clkCPU;
        video_fault_clkCPU    <= video_fault_dvi;
        video_fault           <= video_fault_cpu || video_fault_clkCPU;
    end


    wire [5:0] framebits_w; // Each test-pattern variant should assign this
    reg  [5:0] framebits_r; // Extra register stage, to ease timing
    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            framebits_r <= 0;
        end else begin
            framebits_r <= framebits_w;
        end
    end

    assign pf_status = { //TODO: Use more bits to identify different faults
        video_fault, !video_active,
            framebits_r[5:0], //1-cycle latency avoids overly tight interconnect
        8'b0000_0000 //Maybe for overlay stuff later?
    };


generate
if (COLT45_TESTPAT == 0) begin:_PIXFO_DDREAD_

// *** Normal PixelFeeder activity (DDR -> FIFO) ***
    localparam IDLE = 1'b0, FETCH = 1'b1;
    reg state; // This is a tiny "state machine" of two states!

// CPU-Clocked region (cpu_clk_g)
    reg [63:0] pixel_count;
    reg [ 9:0] head_y, head_x;
    reg [ 5:0] framebits_p, frame_next; // 0=test-pattern, 1=0x1040_0000, 2=0x1080_0000, etc.
    reg interrupt_r;

    assign ffwr_valid = rdf_wren;
    assign ffwr_din = rdf_data; //DDR-read to PIX-write
    assign video = ffrd_dout;
    assign framebits_w = framebits_p;
    assign irq_frame = interrupt_r;
    assign rdf_rden = 1'b1; //TODO: Research RequestController behavior (perhaps shouldn't be always asserted)

//NOTE: High nibble removed; framebits=6, y=10, x=10, low-align=2 ; total 28-bits ("byte" address)
    wire [27:0] head_addr = {framebits_p[5:0], head_y[9:0], head_x[9:0], 2'b00}; // 32-bit word/pixel aligned
    wire last_x = (head_x >= (((SCREEN_WIDTH/X_PIX_PER_CHUNK)-1) * X_PIX_PER_CHUNK));
    wire last_y = (head_y >= (SCREEN_HEIGHT-1));
    wire raf_advance = raf_wren && !raf_full; //NOTE: Always raf_full until we assert raf_wren first!

    assign raf_addr  = {1'b0, head_addr[27:1]}; // Turn byte addr into DDR-address (16-bit spacing)
    //TODO: Is it really appropriate to always assert "raf_wren"???
    assign raf_wren  = 1'b1; //WAS: (state == FETCH); //Declare when FETCH addr ready (but might not happen)

    //Ensures 1+ IDLEs between FETCHs; also note (state==IDLE) ensures !raf_advance
//TEMP:RUN FULL BLAST...    wire next_state = (!ffwr_prog_full && !raf_advance) ? FETCH : IDLE;
    wire next_state = (cpu_rst_r) ? IDLE : FETCH;
    reg fr, fr_r;

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin //Standard reset for other stuff
            state <= IDLE;
            {head_y, head_x, pixel_count} <= 0;
            {framebits_p, frame_next} <= 0;
            {fr, fr_r, interrupt_r} <= 0;
        end else begin
            state <= next_state;
            frame_next <= (pf_vframe) ? `FRAME_BITS(pf_wframe) : frame_next;
            fr_r <= fr;
            interrupt_r <= (fr != fr_r); //Fires 1-cycle after REQ queued (not RESP or PIX)
            // Hold these steady unless logic changes them below...
            fr <= fr;
            head_y <= head_y;
            head_x <= head_x;
            pixel_count <= pixel_count;
            framebits_p <= framebits_p;
            if (raf_advance) begin //Advance x/y/frame (right AFTER end of this cycle)
                pixel_count <= pixel_count + X_PIX_PER_CHUNK;
                if (last_y && last_x) begin
                    fr <= ~fr; // fr transition generates interupt pulse
                    head_y <= 0;
                    head_x <= 0;
                    framebits_p <= frame_next; // Changed to new frame only at end of frame
                end else if (last_x) begin
                    head_y <= head_y + 1;
                    head_x <= 0;
                end else begin
                    head_x <= head_x + X_PIX_PER_CHUNK;
                    //NOTE: Advance by "X_PIX_PER_CHUNK" wastes low bits of "head_x"
                end
            end
        end
    end

// synthesis translate_off
always @(posedge cpu_clk_g) begin
    if (raf_advance && ((head_x == 0) || (last_x && last_y))) begin
        if (last_x && last_y) $display("LAST:");
        $display("  aB:%08h aD:%08h  F:%b X:%04d Y:%04d  PIX:%0d",
                 head_addr, raf_addr,
                 fr, head_x, head_y,
                 pixel_count);
    end
end
// synthesis translate_on

end:_PIXFO_DDREAD_ else if (COLT45_TESTPAT == 1) begin:_PIXFO_SWEEP_

// *** Simple test pattern output THROUGH the FIFO ***
    assign raf_wren = 1'b0;
    assign rdf_rden = 1'b0;
    assign raf_addr = 28'h0;
    assign framebits_w = 0;
    assign irq_frame = 0;

    assign video = ffrd_dout;

    reg [15:0] sweep_RGB; //In cpu_clk_g domain
    reg [63:0] sweep_cnt;
    wire first_x = (sweep_cnt == 0);
    wire last_x = (sweep_cnt == (200 - 1)); //TODO: Compute based on screen size and X_PIX_PER_CHUNK
    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (ffwr_valid && last_x) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (ffwr_valid) begin
            sweep_RGB <= sweep_RGB + 5;
            sweep_cnt <= sweep_cnt + 1; //Sent another 4 pixels
        end else begin
            sweep_RGB <= sweep_RGB; //Hold value steady if not advancing
            sweep_cnt <= sweep_cnt; //Hold value steady if not advancing
        end
    end

    assign ffwr_valid = !ffwr_prog_full; //WAS: !ffwr_full;
    wire [127:0] sweep_pattern = { // Normal pattern (uses "sweep_RGB" value)
                    8'd0, 24'h808080, // Grey stripe
                    8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
                    8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
                    8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]
                };
    assign ffwr_din =
        (first_x) ? {4{32'h00F0FFF0}} : // White stripe
        (last_x)  ? {4{32'h0022FF22}} : // Green stripe
                    sweep_pattern; // Normal pattern (uses "sweep_RGB" value)

end:_PIXFO_SWEEP_ else if (COLT45_TESTPAT == 2) begin:_DIRECT_SWEEP_

// *** DIRECTLY send a pretty and scrolling pattern (NO FIFO) ***
    assign raf_wren = 1'b0;
    assign rdf_rden = 1'b0;
    assign raf_addr = 28'h0;
    assign framebits_w = 0;
    assign irq_frame = 0;

    reg [15:0] sweep_RGB_dvi; //In dvi_clk_g domain
    assign video = {8'h00, sweep_RGB_dvi[15:8], sweep_RGB_dvi[11:4], sweep_RGB_dvi[7:0]};
    assign video_valid = !dvi_rst_r; //WAS: 1'b1

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin
            sweep_RGB_dvi <= 16'hE2A2;
        end else if (video_valid && video_ready) begin
            sweep_RGB_dvi <= sweep_RGB_dvi + 5;
        end else begin
            sweep_RGB_dvi <= sweep_RGB_dvi; //Hold value steady if not advancing
        end
    end

end:_DIRECT_SWEEP_ else if (COLT45_TESTPAT == 3) begin:_DIRECT_PAT_

// *** DIRECTLY inject simple moving pattern gen from FALL-2013-CP1 ***
    assign raf_wren = 1'b0;
    assign rdf_rden = 1'b0;
    assign raf_addr = 28'h0;
    assign framebits_w = 0;
    assign irq_frame = 0;

    PatternGenerator #(
        .CLOCK_HZ(DVI_CLOCK_HZ), //DVI Clock
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .SCENES_PER_SEC(1)
    ) patgen (
        .clock(dvi_clk_g),
        .reset(dvi_rst_r),
        .video(video),
        .video_valid(video_valid),
        .video_ready(video_ready)
    );

end:_DIRECT_PAT_
endgenerate


endmodule

/* Interesting BUG along the way when driving "af_wren" improperly here!!!
    The RequestController doesn't give valid "full" signal unless we TRY to write an address...
    ...so cannot adjust our raf_wren based upon the raf_full signal (like with direct FIFO access).

WARNING:Xst:2170 - Unit ml505top : the following signal(s) form a combinatorial loop: mem_arch/pixel_raf_wren, mem_arch/req_con/fifo_access<5>.
*/
