`timescale 1ns/1ps
/*--------------------------------------------------------------------------------
-- This test-pattern generator was adapted to provide VGA frame/sync signals.
-- 
-- ORIGINAL BASE FILE came from a DIGILENT PmodVGA example in VHDL --
-- Company: Digilent  Engineer: Arthur Brown  Copyright Digilent 2017
--
-- *** Translated to Verilog and "simplified" by Erik Rogers (Feb 2025) ***
-- *** Morphed into a VGA "framer" which generates VGA H&V SYNCs (2025) ***
--------------------------------------------------------------------------------*/

`default_nettype none

module VGAFramer (
    input  wire clk_pix, // MUST match the other resolution parameters (see end of file)
    input  wire rst_pix,

    // Incoming from a video FIFO at clk_pix rate
    input  wire [31:0] video,  // high byte not used
    input  wire video_valid,
    output wire video_ready,

    // Output VGA through PmodVGA (note colors are only 4 bits each)
    output wire VGA_HS_O,
    output wire VGA_VS_O,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B
);
    parameter GEN_PATTERN = 0;

    // See the end of this file for settings for other resolutions.
    //   *** BE SURE TO ADJUST THE CLOCK-WIZARD OUTPUT FREQ ***
    //
    // --***800x600@60Hz***--  Requires 40 MHz clock
    parameter FRAME_WIDTH  =  800;
    parameter FRAME_HEIGHT =  600;
    parameter H_FP         =   40; // H front porch width (pixels)
    parameter H_PW         =  128; // H sync pulse width (pixels)
    parameter H_MAX        = 1056; // H total period (pixels)
    parameter V_FP         =    1; // V front porch width (lines)
    parameter V_PW         =    4; // V sync pulse width (lines)
    parameter V_MAX        =  628; // V total period (lines)
    parameter H_POL = 1, V_POL = 1; // H & V polarity

    // Align the upper-left pixel with beginning of data frame.
    // Wait for first "video_valid" to start scanning and outputting.
    // FIFO logic suppresses "valid" until FIFO is full enough.
    reg waiting = 1;
    always @(posedge clk_pix) begin
        waiting <= waiting; // Default is to hold "waiting" value
        if (rst_pix) begin
            waiting <= 1; // Only reset can return to waiting mode
        end else if (waiting && video_valid) begin
            waiting <= 0; // First "video_valid" clears "waiting"
        end
    end

    wire active;

    reg [11:0] h_cntr_reg = 0;
    reg [11:0] v_cntr_reg = 0;

    reg h_sync_reg     = !H_POL;
    reg v_sync_reg     = !V_POL;
    reg h_sync_dly_reg = !H_POL;
    reg v_sync_dly_reg = !V_POL;

    reg [11:0] VGA_RGB_reg = 0;

    assign video_ready = !rst_pix && !waiting && active;
    wire liveActive = video_ready; // && active;
    wire [11:0] PAT_RGB, VGA_RGB;


//NOTE: VGA-PMOD only supports 4 bits/color, so take upper 4 bits
generate
if (GEN_PATTERN == 1) begin:_PAT_GEN1_

    wire    TT_R = (h_cntr_reg <= (v_cntr_reg +  89)),
            TT_G = (h_cntr_reg <= (v_cntr_reg -   0)),
            TT_B = (h_cntr_reg <= (v_cntr_reg - 130));
    wire    XY_R = (h_cntr_reg %  33 == 0) && (h_cntr_reg %  33 == 1),
            XY_G = (h_cntr_reg %  50 == 0) && (h_cntr_reg %  50 == 2),
            XY_B = (h_cntr_reg % 100 == 1) && (h_cntr_reg % 100 == 5);
    wire [3:0]  T_R = (TT_R || XY_R) ? 4'hF : (v_cntr_reg[3:0]),
                T_G = (TT_G || XY_G) ? 4'hF : (v_cntr_reg[5:2]),
                T_B = (TT_B || XY_B) ? 4'hF : (v_cntr_reg[7:4]);

    assign PAT_RGB  = {T_R, T_G, T_B};

end:_PAT_GEN1_ else begin:_PASS_THRU_VID_

    //NOTE: VGA-PMOD only supports 4 bits/color, so take upper 4 bits
    assign PAT_RGB  = {video[23:20], video[15:12], video[7:4]};

end:_PASS_THRU_VID_
endgenerate


    localparam BORDER_WIDTH = 6, BORDER_HEIGHT = 6;
    wire isLeft   = (h_cntr_reg < BORDER_WIDTH);
    wire isRight  = (h_cntr_reg >= (H_MAX - BORDER_WIDTH));
    wire isTop    = (v_cntr_reg < BORDER_HEIGHT);
    wire isBottom = (v_cntr_reg >= (V_MAX - BORDER_HEIGHT));
    wire isBorder = (isLeft || isRight || isTop || isBottom);

//  .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
// Create a matrix of colors selected by concatenation of the above border signals...
//     case {isLeft, isRight, isTop, isBottom}...
//         0000: Inside frame (not border) -- use pattern or video data
//         0001: Bottom border -- Blueish
//         0010: Top border -- Greenish
//         0100: Right border -- Blueish
//         1000: Left border -- Greenish
//  etc... (Use casez to simplify the "table" logic

    assign  VGA_RGB = (!liveActive)
                        ? 12'h000
                        : (!isBorder)
                            ? PAT_RGB
                            : (isLeft)
                                ? 12'h4F8 // Greenish border
                                : 12'h44F // Blueish border
                        ;
    //CLOCK IS RESPONSIBILTY OF THE ENCOMPASING MODULE

    /*----------------------------------------------------
    -------         SYNC GENERATION                 ------
    ----------------------------------------------------*/

//TODO: I don't think I'm handling front/back porch correctly...
//          If changed, might have to change other "h_cntr_reg/v_cntr_reg" usage
    always @(posedge clk_pix) begin
        if (rst_pix || waiting) begin
            h_cntr_reg <= 0;
            v_cntr_reg <= 0;
            h_sync_reg <= 0;
            v_sync_reg <= 0;
        end else begin
            //NOTE: Ensure the signals are set in EVERY "branch" below... (could default to "hold" values)
            if (h_cntr_reg == (H_MAX - 1)) begin
                h_cntr_reg <= 0;
            end else begin
                h_cntr_reg <= h_cntr_reg + 1;
            end

            if ((h_cntr_reg == (H_MAX - 1)) &&  (v_cntr_reg == (V_MAX - 1))) begin
                v_cntr_reg <= 0;
            end else if (h_cntr_reg == (H_MAX - 1)) begin
                v_cntr_reg <= v_cntr_reg + 1;
            end else begin
                v_cntr_reg <= v_cntr_reg; //Ensure signal gets a value
            end

            if ((h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) &&  (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1))) begin
                h_sync_reg <= H_POL;
            end else begin
                h_sync_reg <= !(H_POL);
            end

            if  ((v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) &&  (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1))) begin
                v_sync_reg <= V_POL;
            end else begin
                v_sync_reg <= !(V_POL);
            end
        end
    end
    
    assign active = ((h_cntr_reg < FRAME_WIDTH) && (v_cntr_reg < FRAME_HEIGHT));

    always @(posedge clk_pix) begin
        //NOTE: Ignore reset. We don't need it.
        v_sync_dly_reg  <= v_sync_reg;
        h_sync_dly_reg  <= h_sync_reg;
        VGA_RGB_reg     <= VGA_RGB;
    end

    assign VGA_HS_O = h_sync_dly_reg;
    assign VGA_VS_O = v_sync_dly_reg;
//TODO: *** Red was in low bits before. Was that based on docs/example??? ***
    assign VGA_R    = VGA_RGB_reg[11:8];
    assign VGA_G    = VGA_RGB_reg[7:4];
    assign VGA_B    = VGA_RGB_reg[3:0];

endmodule


/*
--Sync Generation constants

----***640x480@60Hz***--  Requires 25 MHz clock
--constant FRAME_WIDTH : natural := 640;
--constant FRAME_HEIGHT : natural := 480;
--
--constant H_FP : natural := 16; --H front porch width (pixels)
--constant H_PW : natural := 96; --H sync pulse width (pixels)
--constant H_MAX : natural := 800; --H total period (pixels)
--
--constant V_FP : natural := 10; --V front porch width (lines)
--constant V_PW : natural := 2; --V sync pulse width (lines)
--constant V_MAX : natural := 525; --V total period (lines)
--
--constant H_POL : std_logic := '0';
--constant V_POL : std_logic := '0';

----***800x600@60Hz***--  Requires 40 MHz clock
--constant FRAME_WIDTH : natural := 800;
--constant FRAME_HEIGHT : natural := 600;
--
--constant H_FP : natural := 40; --H front porch width (pixels)
--constant H_PW : natural := 128; --H sync pulse width (pixels)
--constant H_MAX : natural := 1056; --H total period (pixels)
--
--constant V_FP : natural := 1; --V front porch width (lines)
--constant V_PW : natural := 4; --V sync pulse width (lines)
--constant V_MAX : natural := 628; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

----***1280x720@60Hz***-- Requires 74.25 MHz clock
--constant FRAME_WIDTH : natural := 1280;
--constant FRAME_HEIGHT : natural := 720;
--
--constant H_FP : natural := 110; --H front porch width (pixels)
--constant H_PW : natural := 40; --H sync pulse width (pixels)
--constant H_MAX : natural := 1650; --H total period (pixels)
--
--constant V_FP : natural := 5; --V front porch width (lines)
--constant V_PW : natural := 5; --V sync pulse width (lines)
--constant V_MAX : natural := 750; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

----***1280x1024@60Hz***-- Requires 108 MHz clock
--constant FRAME_WIDTH : natural := 1280;
--constant FRAME_HEIGHT : natural := 1024;
--
--constant H_FP : natural := 48; --H front porch width (pixels)
--constant H_PW : natural := 112; --H sync pulse width (pixels)
--constant H_MAX : natural := 1688; --H total period (pixels)
--
--constant V_FP : natural := 1; --V front porch width (lines)
--constant V_PW : natural := 3; --V sync pulse width (lines)
--constant V_MAX : natural := 1066; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

--***1920x1080@60Hz***-- Requires 148.5 MHz clk_pix
--constant FRAME_WIDTH : natural := 1920;
--constant FRAME_HEIGHT : natural := 1080;
--
--constant H_FP : natural := 88; --H front porch width (pixels)
--constant H_PW : natural := 44; --H sync pulse width (pixels)
--constant H_MAX : natural := 2200; --H total period (pixels)
--
--constant V_FP : natural := 4; --V front porch width (lines)
--constant V_PW : natural := 5; --V sync pulse width (lines)
--constant V_MAX : natural := 1125; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';
*/
