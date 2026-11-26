//=============================================================================
// ElipseEngine - midpoint ellipse, ported from the cs150-1245 ISE branch (hardware/src/gpu/ElipseEngine.v).
//
// Draws the outline of an axis-aligned ellipse centred at (xc,yc) with semi-axes a (x) and b (y),
// in four-way symmetry: for every (x,y) step of the first quadrant it issues two ScanLineRunner
// runs, row yc-y and row yc+y, each from column xc-x to column xc+x.  The SLR paints the two end
// pixels in the edge colour; the pixels between them are only painted when the fill colour's top
// (alpha) byte is non-zero (EL_backc_valid captures it; reset value 0 => outline only, which is
// what the GraphicsProcessor gets since it has no BACK command wired to the engine yet).
//
//   Phase A: slope > -1 (x steps every iteration, y when dd >= 0), until AAy - BBx <= AA/2 + BB
//   Phase B: slope <= -1 (y steps every iteration, x when dd < 0), until y == 0
//
// Differences from the ISE copy: the loop-A exit compare is SIGNED (AAy-BBx can step below zero on
// the last iteration; an unsigned compare would see a huge positive number), the debug $display
// calls are compiled out unless ELIP_DEBUG, the port/wire style matches proj150 and the SLR_*
// outputs use the registered xc/yc/frame.
// Arithmetic is modulo 2^32 (like the C model's uint32/int32): AA*BB overflows for big ellipses but
// dd only ever needs its low bits, and |dd| stays < 2^31 for a,b < 1024.
// No clipping: the ellipse must fit on screen (xc-a >= 0, xc+a < 1024, yc-b >= 0, yc+b < 1024).
//=============================================================================
module ElipseEngine #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600
)(
    input  wire         clk, rst,

//Elipse control <=> GPU:
    output wire         EL_ready,       //Can start issuing values/trigger
    input  wire         EL_color_valid, //EL_color captured into "color" (edge color)
    input  wire         EL_backc_valid, //EL_color captured into "backc" (fill color; alpha byte 0 = no fill)
    input  wire [ 31:0] EL_color,       //8-zeros, 3 x 8-bit R/G/B
    input  wire         EL_xc_valid,    //EL_point captured into xc, and/or...
    input  wire         EL_yc_valid,    //  ... yc
    input  wire         EL_a_valid,     //  ... a
    input  wire         EL_b_valid,     //  ... b
    input  wire [  9:0] EL_point,       //Point data with each EL_[xc,yc,a,b]_valid
    input  wire         EL_trigger,     //Trigger drawing (EL_frame captured)
    input  wire [ 31:0] EL_frame,       //Frame-base (modulo 0x0040_0000)

//SLR control (write-only):
    input  wire         SLR_ready,
    output wire         SLR_valid,
    output wire[ 31:0]  SLR_frame,
    output wire[ 31:0]  SLR_color_edge,
    output wire[ 31:0]  SLR_color_fill,
    output wire[  9:0]  SLR_row,
    output wire[  9:0]  SLR_col_start,
    output wire[  9:0]  SLR_col_finish
);

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, <rst>_r, unless really must sync-up release!
    end

// Manage elipse values (each is a register with RVA style "set")
                //Grabbed @clk & trigger  //MUXed to expose value @trigger
    reg  [ 5:0] framebits_r,              framebits;
    reg  [31:0] color_r,                  color;
    reg  [31:0] backc_r,                  backc;
    reg  [ 9:0] xc_r,yc_r, a_r,b_r,       xc,yc, a,b;

    always @(posedge clk) begin
        if (rst_r) begin //Internal reset (don't bog global rst unless needed)
            {framebits_r, color_r, backc_r} <= 0;
            {xc_r,yc_r,   a_r,b_r} <= 0;
        end else if (EL_ready) begin
            {framebits_r, color_r, backc_r} <= {framebits, color, backc}; //Feedback muxed vals
            {xc_r,yc_r,   a_r,b_r}          <= {xc,yc,     a,b};  // since available.
        end
    end

    always @(*) begin //NOTE:Seems OK to lump into one always@* block!
        framebits = framebits_r;
        {color, backc} = {color_r, backc_r};
        {xc,yc, a,b} = {xc_r,yc_r, a_r,b_r};
        if (EL_ready) begin //Preview/capture active inputs up until trigger
            if (EL_trigger)     framebits = EL_frame[27:22];
            if (EL_color_valid) color     = EL_color;
            if (EL_backc_valid) backc     = EL_color;
            if (EL_xc_valid)    xc        = EL_point;
            if (EL_yc_valid)    yc        = EL_point;
            if (EL_a_valid)     a         = EL_point;
            if (EL_b_valid)     b         = EL_point;
        end
    end


//Master-state Hotbit-index (as opposed to full Master-State register value)
    localparam
        MH_RSET     = 0,  //Performing or coming out of reset
        MH_IDLE     = 1,  //Ready for initiation
        MH_PRa1     = 2,  //Prep/Normalize
        MH_PRa2     = 3,  //Prep/Normalize
        MH_PRa3     = 4,  //Prep/Normalize
        MH_SLa1     = 5,  //top-half SLR-write; next-iteration work-ahead
        MH_SLa2     = 6,  //bot-half SLR-write; iteration finalize/advance
        MH_PRb1     = 7,  //Prep for "B"
        MH_PRb2     = 8,  //Prep for "B"
        MH_PRb3     = 9,  //Prep for "B"
        MH_LLb1     = 10, //Adjust vals during loop
        MH_SLb1     = 11, //top-half SLR-write
        MH_SLb2     = 12; //bot-half SLR-write; iteration/done
    localparam MH__LAST = MH_SLb2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET), MS_IDLE = (1<<MH_IDLE),
        MS_PRa1 = (1<<MH_PRa1), MS_PRa2 = (1<<MH_PRa2), MS_PRa3 = (1<<MH_PRa3),
        MS_SLa1 = (1<<MH_SLa1), MS_SLa2 = (1<<MH_SLa2),
        MS_PRb1 = (1<<MH_PRb1), MS_PRb2 = (1<<MH_PRb2), MS_PRb3 = (1<<MH_PRb3),
        MS_LLb1 = (1<<MH_LLb1), MS_SLb1 = (1<<MH_SLb1), MS_SLb2 = (1<<MH_SLb2);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 9:0] x, y, xy_next; // xy_next shared between phase A & B
    reg  [31:0] AA, BB, AABB;  // These stay constant
    reg  signed [31:0] dd, dd_next, stopper; //signed; like "error" in line algorithm

//Iteration adjusted values
    reg  [31:0] AAy, AAy_next, BBx, BB2xp3;
    reg  [31:0] BB2xp2;             //Phase B (== BB2xp3 - BB)
    reg  [31:0] temp_XX, temp_YM1YM1; //Intermediary values for Phase B
    reg  [31:0] temp_BBTX, temp_AAYZ; //Intermediary values for Phase B
    wire signed [31:0] prep_dd_B = temp_BBTX + (BB>>2) + temp_AAYZ - AABB;

//Key Live-Wires & Assigns
    wire advSLR, continueA, continueB;
    wire [ 9:0] xL,xR, yT,yB;

//Synchronous transistions & data-path
    always @(posedge clk) begin
        if (rst_r) cs_M <= MS_RSET; else cs_M <= ns_M;

        case (cs_M)
            MS_RSET: begin
                {x,y} <= 0; //Not much important about reset, better to not-care!
            end
            MS_IDLE: if (EL_trigger) begin
                x       <= 0;               //Start at theta=90 with
                y       <= b;               //  (xc,yc) translated to (0,0)
                BBx     <= 0;               //BB * x;     //(x==0)
            end
        //From MS_PRa1 onward, use registered parameters directly "_r"
            MS_PRa1: begin
                AA      <= a_r * a_r;
                BB      <= b_r * b_r;
            end
            MS_PRa2: begin
                AABB    <= AA * BB;
                AAy     <= AA * b_r;        //(y==b)
                BB2xp3  <= (BB<<1) + BB;    //(x==0)
                dd      <= BB + (AA>>2);    //PARTIAL
                stopper <= (AA>>1) + BB;    //end of first loop
            end
            MS_PRa3: begin
                dd      <= dd - AAy;        //(y==b) and AAy==AAB
            end
            MS_SLa1: if (advSLR) begin
                if (dd >= 0) begin
                    dd_next  <= dd + (AA<<1) - (AAy<<1); //mul32(AA,y<<1)
                    xy_next  <= y - 10'd1;
                    AAy_next <= AAy - AA;
                end else begin
                    dd_next  <= dd;
                    xy_next  <= y;
                    AAy_next <= AAy;
                end
            end
            MS_SLa2: if (advSLR) begin
                if (continueA) begin
                    dd      <= dd_next + BB2xp3; //mul32(BB,(x<<1)+3)
                    y       <= xy_next;
                    AAy     <= AAy_next;
                    x       <= x + 10'd1;
                    BBx     <= BBx + BB;
                    BB2xp3  <= BB2xp3 + (BB<<1);
                end
            end
            MS_PRb1: begin
                //PARTIAL: dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
                temp_XX     <= x * x;
                temp_YM1YM1 <= (y-10'd1) * (y-10'd1);
            end
            MS_PRb2: begin
                temp_BBTX   <= BB * (temp_XX+x);
                temp_AAYZ   <= AA * temp_YM1YM1;
            end
            MS_PRb3: begin
                BB2xp2      <= BB2xp3 - BB; //mul32(BB,(x<<1)+2);
                dd          <= prep_dd_B;   //temp_BBTX + (BB>>2) + temp_AAYZ - AABB;
            end
            MS_LLb1: begin
                if (dd < 0) begin
                    x       <= x + 10'd1;
                    BB2xp2  <= BB2xp2 + (BB<<1);
                end
                //dd += (AA<<1)+AA - (AAy<<1); (+ BB2xp2 first when dd < 0)
                dd          <= dd + ((dd < 0)?BB2xp2:0) + (AA<<1)+AA - (AAy<<1);
                y           <= y - 10'd1;
                AAy         <= AAy - AA;
            end
        endcase
    end

/*
*** FIRST LOOP "A" ***
    while ((AAy-BBx) > stopper) { // (AAy-(AA>>1)) > (BBx+BB)
        if (dd >= 0) {
            dd += (AA<<1) - (AAy<<1); //mul32(AA,y<<1);
            y--; AAy -= AA;
        }
        dd += BB2xp3; //mul32(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
*** SECOND LOOP "B" ***
    uint32_t BB2xp2 = BB2xp3 - BB; //mul32(BB,(x<<1)+2);
    dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
    while (y > 0) {
        if (dd < 0) {
            dd += BB2xp2; //mul32(BB,(x<<1)+2);
            x++; BB2xp2 += (BB<<1);
        }
        dd += (AA<<1)+AA - (AAy<<1); //mul32(AA,y<<1);
        y--; AAy -= AA;
        swpixl_4way(fp,color, xc,yc, x,y);
    }
*/

    assign EL_ready = (cs_M[MH_IDLE]);
    assign xL = (xc_r - x);
    assign xR = (xc_r + x);
    assign yT = (yc_r - y);
    assign yB = (yc_r + y);
    //Slope == -1 exit; SIGNED: the last step can take AAy-BBx below zero (unsigned compare wrapped)
    wire signed [33:0] AAy_m_BBx = $signed({2'b00, AAy}) - $signed({2'b00, BBx});
    assign continueA = (y > 0) && (x <= a_r) && (AAy_m_BBx > $signed({2'b00, stopper}));
    assign continueB = (y > 0);

//Next-State
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (EL_trigger) ns_M = MS_PRa1;
            MS_PRa1: ns_M = MS_PRa2;
            MS_PRa2: ns_M = MS_PRa3;
            MS_PRa3: ns_M = MS_SLa1;
            MS_SLa1: if (advSLR) ns_M = MS_SLa2;
            MS_SLa2: if (advSLR) ns_M = (continueA) ? MS_SLa1 : MS_PRb1;
            MS_PRb1: ns_M = MS_PRb2;
            MS_PRb2: ns_M = MS_PRb3;
            MS_PRb3: ns_M = (continueB) ? MS_LLb1 : MS_IDLE;
            MS_LLb1: ns_M = MS_SLb1;
            MS_SLb1: if (advSLR) ns_M = MS_SLb2;
            MS_SLb2: if (advSLR) ns_M = (continueB) ? MS_LLb1 : MS_IDLE;
            default: ns_M = MS__DEAD;
        endcase
    end


//Write "run" of pixels via ScanLineRunner module
    assign SLR_valid        = (cs_M[MH_SLa1] || cs_M[MH_SLa2] ||
                               cs_M[MH_SLb1] || cs_M[MH_SLb2]),
            SLR_frame       = {4'h1, framebits_r[5:0], 22'b0},
            SLR_color_edge  = color_r,
            SLR_color_fill  = backc_r,
            SLR_col_start   = xL,
            SLR_col_finish  = xR,
            SLR_row         = (cs_M[MH_SLa1] || cs_M[MH_SLb1]) ? yT : yB;

    assign advSLR = SLR_ready && SLR_valid; //Used iif MH_SLax implying SLR_valid


//synthesis translate_off
`ifdef ELIP_DEBUG
    always @(posedge clk) begin
        if (EL_ready && EL_trigger) begin
            #1;
            $display("[=ELIP=]: frame=%h color=0x%h backc=0x%h (%4d,%4d)=>(%4d,%4d)",
                     framebits, color, backc, xc,yc, a,b);
        end
        if (cs_M[MH_PRb1]) $display("%8d ELIP: end of A: x=%0d y=%0d", $time, x, y);
        if (advSLR) $display("%8d ELIP: SLR row=%0d %0d..%0d", $time, SLR_row, SLR_col_start, SLR_col_finish);
    end
`endif
//synthesis translate_on

endmodule
