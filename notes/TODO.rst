=======================================
*** Modern TODOs and critical NOTES ***
=======================================

// DDR3, CACHE, MIGADAPTER, MIG REPAIRS //
==========================================

* [TODO] Figure out the TRUE tunings of Cache bit shifts, truncations, address ranges, etc.
         - Should allow access to FULL DDR3 range by avoiding hi-bit always off.
         - Perhaps ranges from cache.vh need to change (instead of bit shift changes)
* [TODO] dcache_addr has unused high bits... resize/feed them?
* [TODO] Resurrect original Cache.v and re-adapt it for current port renames:
         - Ensure my silly changes are not breaking anything.
         - Re-modify with ONLY critical changes from XUP board.
* [TODO] Use isolated CAF vs WDF FIFO=>MIG channels in MIGAdapter (separate state-machines but WDF first)
* [TODO] Use "defines" for bit ranges??? (which ones???)
* [TODO] MIGAdapter should ensure write data arrives BEFORE the write instruction (to follow spec properly)
* [TODO] Optimize MIGAdapter timing of writes, allowing simultaneous write-data and command.
* [TODO] DREAM FEATURE: DDR3 commands "issued" *when available*:
         - Currently waits for each transaction (read/write) to complete (including reads, due to Cache module)
         - The RequestController would need to track multiple outstanding requests, and match completions.
         - Complex, but would improve throughput significantly.
* [TODO] FIFOs between CPU <--> MIGAdapter could handle 128-bit <--> 64-bit (or even 256 vs. 64) transfers.
         - If 256-bit, then would require Cache module and ALL other DDR3 accessors to handle 256-bit data.
         - Would improve throughput by reducing number of transactions.

// SOFTWARE / TOOLS / SCRIPTS //
================================
* [TODO] New GIOS commands:
             - Add "xor" without "copy" or "file".
             - Add "compare" command between two memory ranges.
             - Add "fill" command, repeat word x number of times.
* [TODO] GIOS: Add option to dump memory contents to a file (binary or hex/ascii)???
* [TODO] Quick "PUNCH" of binary data into various BRAMs (bios, dmem, etc.). Avoid IP rebuild.
* [TODO] Make coe_to_serial and hex_to_serial.py compute XOR or other checksum and display it.

// CLOCKING and RESETS //
=========================
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
