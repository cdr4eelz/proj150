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
    output wire[ 15:0]  pf_status, //Composite status ("ready" signal not present/used)
    output wire         irq_frame     //1-cycle pulse after frame transition (except startup frame)
);

    // Hint: States of a mini state machine!
    localparam IDLE = 1'b0, FETCH = 1'b1;

    localparam X_PIX_PER_CHUNK = 8; //Number of pixels (32-bit words) to advance per DDR request
    //TODO: Compute other localparams based on this, like "framebits" size and "last_x" condition!

// Use FIFO's separate "busy" signals and register the "combinational" reset signal
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE" *)
    reg  cpu_rst_r, dvi_rst_r; // Release synchronously to each clock
    wire wr_rst_busy, rd_rst_busy; // Driven by FIFO
    always @(posedge cpu_clk_g) begin
        cpu_rst_r <= cpu_rst_g || wr_rst_busy;
    end
    always @(posedge dvi_clk_g) begin
        dvi_rst_r <= dvi_rst_g || rd_rst_busy;
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

/* ABANDONED VIDEO GENERATION CODE (LEFT COMMENTED HERE TEMPORARILY). Only feeder_running was in use elsewhre.
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


    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is reasonably full (custom "prog_full"). Other "fullness" signals are debug.
    wire [127:0] feeder_data;
    wire         feeder_wren, feeder_full, almost_full, prog_full;
    wire [ 31:0] feeder_raw, feeder_dout;
    wire         feeder_empty, feeder_valid;

    assign feeder_dout = {8'h00, feeder_raw[23:16], feeder_raw[15:8], feeder_raw[7:0]};
    assign rdf_rden    = 1'b1; //Always ready to read (want to fill up)! //TODO: Use FIFO signal to pace this!

    //Additional signals for debugging
    wire wr_ack, overflow, underflow;

//TODO:Insert DDRStage before pixel_fifo to allow LITTLEWORDIAN flip
generate if (COLT45_TESTPAT <= 1) begin:WITH_FIFO
//TODO: Rename "feeder_XYZ" signals to distinguish in/out, rd/wr, & cpu/dvi clock domain
    wire prog_empty, fifo_rd_en;
    pixel_fifo pf_fifo (
        .rst(cpu_rst_g), //FIFO does internal clock syncs (see "busy" signals)
        //WRITE: CPU clock domain
        .wr_clk(cpu_clk_g),         // input
        .full(feeder_full),         // output
        .almost_full(almost_full),  // output
        .prog_full(prog_full),      // output
        .wr_en(feeder_wren),        // input               rdf_wren
        .din(feeder_data),          // input wire [127:0]  rdf_data
        .wr_rst_busy(wr_rst_busy),  // output

        //READ: DVI clock domain
        .rd_clk(dvi_clk_g),         // input
        .empty(feeder_empty),       // output
        .prog_empty(prog_empty),    // output  NOTE: Custom "prog_empty" is set to near full!
        .rd_en(fifo_rd_en),         // input   WAS: video_ready
        .valid(feeder_valid),       // output  TODO: Use "valid" signal for diagnostics (set a fault)
        .dout(feeder_raw),          // output  NOTE: Ignoring "valid" signal (allow underflow???)
        .rd_rst_busy(rd_rst_busy),  // output

        //EXTRA: Mostly for debug
        .wr_ack(wr_ack),            // output
        .overflow(overflow),        // output
        .underflow(underflow)       // output
    );

    // Wait for FIFO to be full enough before we start offering video to be read from it
    reg fifo_running = 0;
    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin
            fifo_running <= 0; // Only reset can clear FIFO running mode
        end else begin
            fifo_running <= fifo_running; // Default is to hold current value
            if (!prog_empty) begin //NOTE: !prog_empty set to desired full target
                fifo_running <= 1; // Start offering video if FIFO is "full enough"
            end
        end
    end

    // Block both ready/valid signals to postpone video xfer until FIFO is full enough
    assign fifo_rd_en = fifo_running && video_ready;
    assign video_valid = fifo_running && feeder_valid;
    
end endgenerate

//TODO: Use REAL synchronizers for cross-clock signals!
//FAULT and ACTVE detection
    reg  video_fault_dvi, video_fault_cpu, video_fault, video_active;

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  video_active_clkCPU, video_fault_clkCPU;

    (* EQUIVALENT_REGISTER_REMOVAL="OFF" *)
    reg  [7:0] video_active_dvi, video_active_cpu;

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin //WAS: dvi_rst_g
            video_fault_dvi <= 1'b0;
        end else if (video_ready && video_valid && feeder_empty) begin
            video_fault_dvi <= 1'b1; //DVI-side fault if we run out of pixels
        end else if (underflow || (video_ready && feeder_empty)) begin
            //TODO: Could this just be "underflow" flag?
            video_fault_dvi <= 1'b1;
        end

        video_active_dvi[7:0] <= {video_active_dvi[6:0], (video_ready && video_valid)};
    end

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_g) begin
            video_fault_cpu <= 1'b0;
        end else if (feeder_wren && feeder_full) begin //TODO: Could this just be "overflow" flag?
            video_fault_cpu <= 1'b1;
        end

        //TODO: This whole "shift register" business is a hacky sub for sync...
        video_active_clkCPU   <= |video_active_dvi;
        video_active_cpu[7:0] <= {video_active_cpu[6:0], video_active_clkCPU};
        video_active          <= |video_active_cpu || video_active_clkCPU;
        video_fault_clkCPU    <= video_fault_dvi;
        video_fault           <= video_fault_cpu || video_fault_clkCPU;
    end


generate if (COLT45_TESTPAT == 0) begin:PIXFO_DDREAD
// *** Normal PixelFeeder activity (DDR -> FIFO) ***

    assign feeder_wren = rdf_wren;
    assign feeder_data = rdf_data; //DDR-read to PIX-write
    assign video = {8'h00, feeder_dout[23:0]};

// CPU-Clocked region (cpu_clk_g)
    reg [63:0] pixel_count;
    reg [ 9:0] head_y, head_x;
    reg fr, fr_r, interrupt_r;
    reg [ 5:0] framebits, framebits_r, frame_next; // 0=test-pattern, 1=0x1040_0000, 2=0x1080_0000, etc.
    reg state; // This is a tiny "state machine" of two states!

//NOTE: High nibble removed; framebits=6, y=10, x=10, low-align=2 ; total 28-bits ("byte" address)
    wire [27:0] head_addr = {framebits[5:0], head_y[9:0], head_x[9:0], 2'b00}; // 32-bit word aligned
    wire last_x = (head_x >= (((SCREEN_WIDTH/X_PIX_PER_CHUNK)-1) * X_PIX_PER_CHUNK));
    wire last_y = (head_y >= (SCREEN_HEIGHT-1));
    wire raf_advance = raf_wren && !raf_full; //NOTE: Always raf_full until we assert raf_wren first!

    assign raf_addr  = {1'b1, head_addr[27:1]}; // Turn into DDR-address (16-bit spacing)
    assign raf_wren  = 1'b1; //WAS: (state == FETCH); //Declare when FETCH addr ready (but might not happen)
    assign irq_frame = interrupt_r;
    assign pf_status = {
        video_fault, !video_active,
            framebits_r[5:0], //1-cycle latency avoids overly tight interconnect
        8'b0000_0000 //Maybe for overlay stuff later
    };

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            {frame_next, framebits_r, interrupt_r} <= 0;
        end else begin
            framebits_r <= framebits;
            interrupt_r <= (fr != fr_r); //Fires 1-cycle after REQ queued (not RESP or PIX)
            if (pf_vframe) begin
                frame_next <= `FRAME_BITS(pf_wframe); //Either addr style
            end else begin
                frame_next <= frame_next; // Ensure signal doesn't go unassigned
            end
        end
    end

    //Ensures 1+ IDLEs between FETCHs; also note (state==IDLE) ensures !raf_advance
    wire next_state = (!prog_full && !raf_advance) ? FETCH : IDLE;

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin //Standard reset for other stuff
            state <= IDLE;
            fr_r <= 0;
            {fr, head_y, head_x, pixel_count} <= 0;
            framebits <= frame_next;
        end else begin
            state <= next_state;
            fr_r <= fr;
            // Hold these steady unless logic changes them below...
            fr <= fr; head_y <= head_y; head_x <= head_x;
            pixel_count <= pixel_count; framebits <= framebits;
            if (raf_advance) begin //Advance x/y/frame (right AFTER end of this cycle)
                pixel_count <= pixel_count + X_PIX_PER_CHUNK;
                if (last_y && last_x) begin
                    fr <= ~fr; // fr & fr_r are used to generate interupt pulse
                    head_y <= 0; head_x <= 0;
                    framebits <= frame_next; // Changed to new frame only at end of frame
                end else if (last_x) begin
                    head_y <= head_y + 1; head_x <= 0;
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

end else if (COLT45_TESTPAT == 1) begin:PIXFO_SWEEP
// *** Simple test pattern output THROUGH the FIFO ***
    assign video = {8'h00, feeder_dout[23:0]};
    assign raf_wren = 1'b0;

    reg [15:0] sweep_RGB; //In cpu_clk_g domain
    reg [63:0] sweep_cnt;
    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (feeder_wren && (sweep_cnt == (200 - 1))) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (feeder_wren) begin
            sweep_RGB <= sweep_RGB + 5;
            sweep_cnt <= sweep_cnt + 1; //Sent another 4 pixelssweep_RGB
        end
    end

    assign feeder_wren = !prog_full; //WAS: !feeder_full;
    assign feeder_data = {
        8'd0, 24'h808080, // Grey stripe
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]
    };

end else if (COLT45_TESTPAT == 2) begin:DIRECT_SWEEP
// *** DIRECTLY send a pretty and scrolling pattern (NO FIFO) ***
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

end else if (COLT45_TESTPAT == 3) begin:DIRECT_PAT
// *** DIRECTLY inject simple moving pattern gen from FALL-2013-CP1 ***
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
end endgenerate

endmodule

/* Interesting BUG along the way when driving "af_wren" improperly here!!!
    The RequestController doesn't give valid "full" signal unless we TRY to write an address...
    ...so cannot adjust our raf_wren based upon the raf_full signal (like with direct FIFO access).

WARNING:Xst:2170 - Unit ml505top : the following signal(s) form a combinatorial loop: mem_arch/pixel_raf_wren, mem_arch/req_con/fifo_access<5>.
*/
