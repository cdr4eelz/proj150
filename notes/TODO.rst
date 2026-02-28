=======================================
*** Modern TODOs and critical NOTES ***
=======================================

*** Consider defining VGAPixels as only 4-bit per channel (12-bit total)
        Allows twice the density in FIFOs and memory, and less "bandwidth"
        between GPU and DDR3 (which has high latency). The VGA-PMOD wonly
        has 4-bits per channel anyway. As a ridiculous option, the 12-bits
        could be packed and unpacked in the FIFOs and memory, to squeeze
        20 pixels * 12 bits-per-pixel = 240 bits (wasting 256-240=16 bits).
        Even 21 pixels per transaction would be possible if tolerating an
        odd packing arrangement. Some hardware assistance could shelter
        most modules in the video pipelines with the odd pack/unpack stage:
            Current 32-bits/pixel == 8 pix/tran;
            Max 12-bits/pixel == 21/transaction (only 4 bits wasted);
            Simpler 12-bits/pixel == 20/transaction (with 16 bits wasted).
*** Combined pixel packing with lower resolution, {4-xtra,4-R,4-G,4-B}...
        640x480 == 307200 pix/frame:
            2457600 bytes/frame (307200 / ) @ 32-bits/pix (8 pix/trans * 256 bits/tran)
            xyz bytes/frame @ 16-bits/pix 20 pix/tran / 256 pix/tran == 12288 transactions/frame @ 32-bits/pixel.
            21 pix/2560 pix/transaction == 11657 transactions/frame @ 12


On deck:
    For each "named-block" (like begin:name"), ensure "end:name" is used too.
    On all FIFOs, adhear to wr_rst_busy/rd_rst_busy signals.
    Pixel FIFO has reset OUTPUTS that should pause their use until resets done.
    Enforce a minimum reset duration (and de-assert CPU last???).
    Put key reset signal on global "clock" buffer.
    Compute xor and checksum in coe_to_serial (and maybe hex_to_serial.py)
    Round coe_to_serial "file upload" size to nearest 32-bit size (pad with zeros?)
    Compute actual checksum for anything (rather than just XOR).
    Adjust PixelFeeder read-ready when FIFO is "full".
    VGAFramer wait at first pixel until FIRST valid video arrives...
        PixelFeeder must hold video_valid low until FIFO reaches target fullness.
        Use "almost_full/empty" or estimated fullness or custom threshold to trigger ready signal.
        Currently, VGAFramer never examines video_valid!
        It is true, however, that once started (at first video_valid) it must fetch every PIX cycle.
        Would it be overkill to have a short shift-register?
        Any underflow by VGAFramer is a fault (could it recover somehow?)
        Perhaps upper byte of pixel data could help synchronize (especially after a fault)?
        Would it be acceptable to hold reset until first video_valid?
    Disable VGA from DDR to see if GIOS reads & writes become solid again.
    Clean out PixelFeeder/VGAFramer conditional synth (alternate video).
    PixelFeeder uses backogus "synchronizers" (maybe elsewhere too).
    Remove "hysteresis" from Pixel FIFO to avoid stammering fetches from memory.
    Utilize "busy" signals from ALL FIFOs.


// DDR3, CACHE, MIGADAPTER, MIG REPAIRS //
==========================================
* [TODO] Figure out the TRUE tunings of Cache bit shifts, truncations, address ranges, etc.
         - Should allow access to FULL DDR3 range by avoiding hi-bit always off.
* [TODO] dcache_addr has unused high bits... resize/feed them?
* [TODO] Resurrect original Cache.v and re-adapt it for current port renames:
         - Ensure my silly changes are not breaking anything.
         - Re-modify with ONLY critical changes from XUP board.
* [TODO] Use isolated CAF vs WDF FIFO=>MIG channels in MIGAdapter (separate state-machines but WDF first)
* [TODO] Use "defines" for bit ranges??? (which ones???)
* [TODO] Optimize MIGAdapter timing of writes, allowing early and simultaneous write-data2 and command.
            - Currently, command is sent only AFTER write data is accepted.
            - Per MIG spec, write data can be sent simultaneously or earlier than command.
            - Could separate state-machines for WDF and CAF FIFOs, with WDF state holding back CAF state.
* [TODO] DREAM FEATURE: DDR3 commands "issued" *when available*:
         - Currently waits for each transaction (read/write) to complete (including reads, due to Cache module)
         - The RequestController would need to track multiple outstanding requests, and match completions.
         - Complex, but would improve throughput significantly.
* [TODO] FIFOs between CPU <--> MIGAdapter could handle 128-bit <--> 64-bit (or even 256 vs. 64) transfers.
         - If 256-bit, then would require Cache module and ALL other DDR3 accessors to handle 256-bit data.
         - Would improve throughput by reducing number of transactions.
* [TODO] Verify that Cache is working properly with MIGAdapter and DDR3.
         - Add debug probes and ILA to monitor key signals.
         - *** Once other modules are fetching their 256-bit data, mis-alignments might emerge in Cache.

// SOFTWARE / TOOLS / SCRIPTS //
================================
* [TODO] New GIOS commands:
             - Add "xor" without "copy" or "file" (can just copy to 0x0000_0000 as workaround)
             - Add "compare" command between two memory ranges.
             - Add "fill" command, repeat word x number of times.
* [TODO] GIOS: Add option to dump memory contents to a file (binary or hex/ascii)???
* [TODO] Quick "PUNCH" of binary data into various BRAMs (bios, dmem, etc.). Avoid IP rebuild.
* [TODO] Make coe_to_serial and hex_to_serial.py compute XOR or other checksum and display it.
* [TODO] GIOS: Add option to specify chunk size of "dump". (Like a "setting" one can adjust)
* [TODO] Upload command ("file") doesn't seem to calculate XOR into "result".
* [TODO] GIOS: Add option to verify uploaded data against local file (XOR, chksum, or full compare).
* [TODO] GIOS: Add option to specify endianness when dumping memory???
* [TODO] GIOS: Add option to specify ASCII vs. HEX output when dumping memory (or combo).
* [TODO] GIOS: Utility command to do automated thorough memory test (write/read/verify).
* [TODO] GIOS: Add some "status" values (like current Stack-Pointer, etc.).
* [TODO] GIOS: Simple line editing in GIOS (like "backspace" or "clear line") would be nice.

// CLOCKING and RESETS //
=========================
* [TODO] Use Debouncer.v & ButtonParser.v rather than custom crap.
* [TODO] Pass some reset signals through BUFGs.
* [TODO] Utilize "XPM_CDC" built-in macros for clock-crossing (synchronizers)
* [TODO] Remove combinational logic (or REGister it) going into CDC synchronizers
* [TODO] Note that ILA identifies mixed-clocks for app_cmd, f_cmd, f_addr, f_addr_base...why?
* [TODO] DRC reports BRAMs should use SYNCHRONOUS reset signals (avoid warning of unknown severity)
* [TODO] Avoid general FALSE-PATH constraints (make them specifically between two points REG-REG)
* [TODO] Run through entire CDC report to clean worst stuff and maybe most warnings?
* [TODO] Simplify RESET "tree" (make all synchronous resets?) and address CDC propagation of the signal
* [TODO] Avoid unneeded reset for signals that don't matter, when key reset response is sufficient

// XILINX or OTHER techniques and rules //
==========================================
* [TODO] Per "UG896" you must upgrade all IP prior to adding a COE file.
* [TODO] Per "UG896" locate the COE file in the same directory as the XCI file.
* [TODO] Remove DEBUG property from actual signals/regs and tag TAP_<Module-code>_XYZ on XYZ signal.
             - This helps keep module looking clean by organizing all TAPs at bottom.
             - TAG module ports easily (TAP gets marked as debug) which is otherwise not an option.
             - TAGs become optional, either comment them out or use an enabling parameter to skip them.

// DREAM FEATURE or CHALLENGES or UNCRITICAL //
===============================================
* [TODO] SOMEHOW figure out how to join cs150 with proj150 git history!!!
* [TODO] SOMEHOW interface MIPS CPU witM TODO anh an AXI (lite and stream?) Can span CPU<->MIG clock domains?
* [TODO] Actually scan warnings for useful entries (perhaps after connecting rest of memory modules)
* [TODO] Try upgrading project to newer version (latest???) and regen IP.
* [TODO] Only use 1 bit of caf for READ/WRITE (synth eleminates unused bits anyway)


===============================================
// COMPLETED TASKS or HISTORIC NOTES //
===============================================

* -done- Verify bit width of OLD DDR3 accessors (Cache.v, GPU, etc.) Was 128-bit x 2 = 256-bit?
* -done- Use actual TODO document rather than cluttering this one!
* -done- Insert SPACE after colon in GIOS.dump, in all data listings (dump & lw)
* -done- Remove DEBUG property from all "icache" lines
* -done- Writes not fully implemented... second chunk ignored?
* -done- MIGAdapter should ensure write data arrives BEFORE the write instruction (to follow spec properly)
* -done- Cache module: Re-enable Cache module and quick tests. (Follow with debug probes and ILA)
