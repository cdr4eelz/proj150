# proj150

Possibly temporary informal transplant of the cs150 project in order to port things to a modern dev board such as the Arty A7.
The initial port was a manual attempt that was buggy; it was later patched up with help from Grok Bot.

The CS150 MIPS150 project (`cs150-1245`, ISE branch) ported to Vivado 2019.1, non-project mode: MIPS CPU, UART, VGA + GPU and a
write-through cache in front of DDR3. Target board: **Digilent Arty A7-100T** (`xc7a100tcsg324-1`). A
PYNQ-Z2 target is planned (`BOARD=pynq-z2`, see below) but not written yet.

The build is a plain **Makefile + Tcl, Vivado non-project mode**, like the ISE flow in `cs150`
(`make synth / impl / bit / timing / program`). There is no Vivado project (`.xpr`) and none is needed:
every IP core is generated from the Tcl scripts in `ip/` and `boards/*/ip/`.

## Background

proj150 started as a quick, admittedly sloppy migration of the `cs150` repo into a GUI-based Vivado
project, to avoid first working out a command-line make/Tcl flow in `cs150`. It was not created as a
fork of `cs150`, and at the time it was not certain that every file needed to rebuild the project was
committed. The non-project make build ([#3](https://github.com/cdr4eelz/proj150/pull/3)) and the ISE
port (see Port history) replaced that setup.

## Build

Needs Vivado **2019.1** (MIG 7-series 4.2, clk_wiz 6.0, fifo_generator 13.2, blk_mem_gen 8.4) and, for
`make sim`, Icarus Verilog. `make` finds `vivado` on `PATH` and falls back to
`/tools/Xilinx/Vivado/2019.1/bin/vivado`; override with `VIVADO=...`.

```
make bit SW_STALL_EN=0      # IP + synthesis + place&route + bitstream  ->  build/arty/proj150_arty.bit
make timing                 # WNS/WHS and utilization of the routed design
make program                # load it into the Arty (Digilent cable only)
make sim                    # ISE-ported Icarus tests (sim/ise) + MemoryDDR/GPU regression
```

A clean `make bit` runs everything: about 4 min for the IP (the MIG is most of that; the IP are built
in parallel), then synthesis and implementation. Later runs only redo what changed.

| Target | What it does |
| --- | --- |
| `make ip` | Generate and out-of-context synthesize every IP: `build/<board>/ip/<name>/<name>.{xci,dcp}`. Several Vivado instances at once (`IP_JOBS=4`). |
| `make synth` | `synth_design` of `ArtyA7top` -> `build/<board>/synth/post_synth.dcp`. |
| `make impl` | opt, place, phys_opt, route -> `build/<board>/impl/post_route.dcp`, reports in `build/<board>/reports/`. Fails on unrouted nets or negative setup/hold slack. |
| `make bit` | Bitstream `build/<board>/proj150_arty.bit`. Re-checks the timing gate, so a failing `impl` cannot be turned into a bitstream. |
| `make timing` | Prints WNS/WHS, writes `build/<board>/timing.txt` (slack plus LUT/FF/BRAM/DSP use). |
| `make program` | Programs the Arty over its **Digilent** JTAG cable, selected by serial (`HW_SERIAL`, see `boards/arty/board.mk`). Never opens other cables, e.g. the Xilinx Platform Cable USB II of the XUPV5. |
| `make mmi` | Memory map of the four block RAMs for `updatemem`: `build/<board>/proj150_arty.mmi` (see *Patching a RAM image into a bitstream*). Reads `post_route.dcp`, never rebuilds. |
| `make patch COE=sw/gios.inst.coe` | Swap one RAM image into the **existing** bitstream with `updatemem`, no rebuild: `build/<board>/proj150_arty_patched.bit`. `make patch-bios`, `patch-dmem`, `patch-imem`, `patch-isr` do the same for the four `sw/` images. A test aid, not a build. |
| `make sim` | First `make sim-ise`: the unit, CPU and GPU tests carried over from the cs150-1245 ISE Icarus rig (`sim/ise`, see its README; uses the cs150 checkout at `CS150`, default `../cs150-1245`). Then `sim/icarus/run_icarus.sh`: memory path, PixelFeeder and GPU against a behavioural MIG. No Xilinx tools needed. |
| `make clean` | Remove `build/<board>`. `make clean-impl` keeps the generated IP; `make clean-ip` removes only the IP. |
| `make all` | `bit` + `timing` (default goal). `make help` prints the header of the Makefile. |

Parameters, on the command line (`make bit SW_STALL_EN=0`):

| Variable | Meaning |
| --- | --- |
| `BOARD=arty` | Board directory under `boards/` (default `arty`). Build outputs go to `build/<board>/`. |
| `SW_STALL_EN=0` | `ArtyA7top` parameter: ignore `SWITCH[1]` (stall the CPU). Use for bring-up builds. |
| `GENERICS="A=1 B=2"` | Any other top-level parameter overrides. Changing them rebuilds from synthesis on. |
| *(sticky)* | Parameters given once are remembered in `build/<board>/synth.params`: `make timing` or `make program` after `make bit SW_STALL_EN=0` use that build. `make bit GENERICS=` goes back to the defaults. |
| `TIMING_GATE=0` | Write the bitstream even with negative slack (debugging only). |
| `IP_JOBS=4`, `VIVADO=...`, `HW_SERIAL=...` | Parallel IP builds, Vivado binary, Digilent cable serial. |
| `COE=`, `MEM=`, `PATCH_IN=`, `PATCH_OUT=`, `PATCH_FORCE=1`, `MMI_VERIFY=0` | `make patch` / `make mmi` only, see below. |

### Patching a RAM image into a bitstream

Changing the software (the `sw/*.coe` block RAM images) normally means `make ip` and a full rebuild. For a
quick test, `updatemem` (Vivado's replacement for ISE's `data2mem` / `bitgen -g UpdtBRAM`) can swap one image
inside the finished bitstream in seconds, with no synthesis or place and route:

```
make bit                                   # once: the bitstream to patch
make patch-bios                            # sw/gios.inst.coe  -> bios_mem  -> build/arty/proj150_arty_patched.bit
make patch COE=sw/gios.inst.coe            # the same; MEM=bios|dmem|imem|isr when the file is not one of the sw/MANIFEST names
make patch-dmem PATCH_IN=build/arty/proj150_arty_patched.bit PATCH_OUT=build/arty/p2.bit    # chain a second image
vivado -mode batch -source scripts/program.tcl -tclargs build/arty/proj150_arty_patched.bit 210319BCC332A localhost:3121 'xc7a100t*'
```

| Memory (`-proc`) | IP | `sw/` image | Primitives |
| --- | --- | --- | --- |
| `bios` | `bios_mem` | `gios.inst.coe` | 16 x RAMB18, 2 bits each |
| `dmem` | `dmem_blk_ram` | `bench.inst.coe` | 4 x RAMB36, one byte lane each |
| `imem` | `imem_blk_ram` | `proj7.inst.coe` | 4 x RAMB36, one byte lane each |
| `isr` | `isr_mem` | `isr7.coe` | 4 x RAMB36, one byte lane each |

How it works: `scripts/mmi.tcl` (`make mmi`, run automatically by `make patch`) opens
`build/<board>/impl/post_route.dcp` and writes `build/<board>/proj150_arty.mmi`, with one Processor and
AddressSpace per memory (the UG1580 format) and the location and bit slice of every primitive.
`write_mem_info` cannot do that: it only knows MicroBlaze and PS7 designs. The primitives are found as the
`RAMB18E1`/`RAMB36E1` cells below the instance whose `REF_NAME` is the IP. The bit slice each one holds is not
assumed: the `INIT_xx` of every primitive is decoded and compared, word for word, with the image the IP was built
from (the `.mif` that blk_mem_gen wrote in `build/<board>/ip/<ip>/`, else the COE named in its `.xci`). The MMI
is only written if every lane matches, otherwise `make mmi` fails and says which primitives differ. That
usually means the IP was regenerated after the last `make impl`: run `make bit`. `MMI_VERIFY=0` skips the check
and assumes blk_mem_gen's `ramloop[k]` = bit slice `k` order (unsafe). `scripts/coe2mem.tcl` (`tclsh` or
`vivado -mode batch`) converts the COE to the `.mem` file `updatemem` reads: `@0000`, then one 32-bit hex word
per line, zero padded to the RAM's 4096 words.

Caveats:

* A patched bitstream is a **test artifact**. The IP, the checkpoints and the Makefile's rebuild tracking still
  hold the old image, and the next `make bit` rebuilds from `sw/`, not from your patch. Put the change into
  `sw/` (`make sw-import`) before a real build.
* The MMI records where the block RAMs were placed, so patch only a bitstream written from the **same routed
  checkpoint** the MMI was made from. `make mmi` regenerates the MMI when `post_route.dcp` is newer, and
  `make patch` refuses a bitstream older than the checkpoint (`PATCH_FORCE=1` overrides).
* The RAMs are fixed at 4096 words (`PATCH_DEPTH`). A shorter image is zero padded like the IP does; a longer one is an
  error, and needs a full rebuild.
* `make patch` never builds anything: without `build/<board>/proj150_arty.bit` and `post_route.dcp` it stops.

### What triggers a rebuild

* **IP**: an IP is regenerated only when its own `ip/<name>.tcl` (or `boards/<board>/ip/<name>.tcl`),
  a file it reads (the `.coe` of the block RAMs, `mig_arty_a7_100.prj`), or `scripts/ip.tcl` /
  `scripts/common.tcl` changes. Edit one FIFO threshold and only that FIFO is rebuilt.
* **Synthesis**: any `.v`/`.vh` under `proj150.srcs/sources_1/imports/src`, `scripts/sources.tcl`, the
  `.xdc`, the IP, or the parameters.
* **Implementation / bitstream**: the previous stage's checkpoint.

New Verilog files must also be added to `scripts/sources.tcl`.

## Layout

```
Makefile                  targets above
boards/arty/board.mk      part, top, constraints, IP list, JTAG cable
boards/arty/ip/           Arty-specific IP: clk_wiz_0 (single MMCM), MIG (create_ip Tcl + mig_arty_a7_100.prj)
boards/pynq-z2/board.mk   placeholder (errors out)
ip/*.tcl                  board independent IP: mig_caf/mig_wdf/mig_rdf, pixel_fifo, the block RAMs
scripts/*.tcl             ip, synth, impl, bit, timing stages, program.tcl, sources.tcl (RTL list)
scripts/tools/xci2tcl.tcl one-off: turn a GUI-made .xci into an ip/*.tcl (how ip/*.tcl were made)
proj150.srcs/             RTL (`sources_1/imports/src`), constraints, COE files, the xsim-only `sim_1`
sim/icarus/               Icarus harness (`make sim`)
hwtest/                   UART driver and logs for on-board tests (GIOS)
```

## IP

The IP are created in a throwaway in-memory Vivado project: `create_ip` + `set_property -dict CONFIG...`,
then `generate_target` and `synth_ip` (`scripts/ip.tcl`); the `.xci` under `build/` is only an output.
The MIG comes from `boards/arty/ip/mig_arty_a7_100.prj`, the configuration proven on hardware: native
UI, 4:1, 3077 ps (325 MHz), 128-bit UI data, `sys_clk_i` 100 MHz and `clk_ref_i` 200 MHz from one MMCM
(`clk_wiz_0`, CLKOUT4 is the MIG system clock). `mig_caf` has `prog_full` at 24, `mig_rdf` at 400,
`pixel_fifo` 448/447 and prog_empty 1600/1601; the comments in the `ip/*.tcl` say why.

To change an IP: edit its Tcl, run `make ip`. To start from the Vivado GUI instead, customize the
core in a scratch project and run
`vivado -mode batch -source scripts/tools/xci2tcl.tcl -tclargs path/to/core.xci ip/core.tcl [board_part]`.

## Boards

`BOARD=arty` is the only board. `BOARD=pynq-z2` (`xc7z020clg400-1`) is reserved: the board has no
PL-side DDR, so memory would go through the Zynq PS (S_AXI_HP/ACP) behind the `MemoryDDR` interface.
`boards/pynq-z2/board.mk` explains what a new board directory needs.

## Port history

Before the ISE port, the Arty bring-up and build:

1. [#1](https://github.com/cdr4eelz/proj150/pull/1) `timing_fixes`: timing fixes (Jan 2026).
2. [#2](https://github.com/cdr4eelz/proj150/pull/2) `ddr-fix`: fix the DDR3/MIG path and PixelFeeder underrun.
3. [#3](https://github.com/cdr4eelz/proj150/pull/3) `make-build`: Makefile + Tcl non-project build (no `.xpr`).
4. [#4](https://github.com/cdr4eelz/proj150/pull/4) `ellipse-fix`: port the working ISE ellipse engine so hwelip finishes.

The ISE port then landed as six stacked PRs, merged in order with merge commits (history kept); `master` at `ea3e210`:

5. [#5](https://github.com/cdr4eelz/proj150/pull/5) `port-sim-rig`: ISE Icarus sim rig import (`sim/ise`).
6. [#6](https://github.com/cdr4eelz/proj150/pull/6) `port-cpu-fixes`: CPU pipeline fixes and COP0.
7. [#7](https://github.com/cdr4eelz/proj150/pull/7) `port-gpu-v2`: GPU v2, 4-bit GOPs, RectangleEngine.
8. [#8](https://github.com/cdr4eelz/proj150/pull/8) `port-mmio-uart`: UART and MMIO.
9. [#9](https://github.com/cdr4eelz/proj150/pull/9) `port-bram-map-apps`: `sw/` folder and MemBank.
10. [#10](https://github.com/cdr4eelz/proj150/pull/10) `port-sim-system`: system sims and hardware tests (`hwtest/`).

On the Arty every hardware test stage passed (banner, dcache, icache, pixfeed, gpu, elip with 134/134
pixel reads and 547 row checksums matching, elipbig 36/36 and 600 rows), and `jal 60000000` ran the
proj7 app at about 60 fps.

Queued next: a cleanup PR that removes the duplicate UART IOB register stage (Place 30-73) and fixes
the `VGAFramer` vertical sync compare so the declared front/back porch of 1/23 lines is realized.

## Notes

* Outputs under `build/` are ignored by git.
* `make program` is volatile (lost at power-off) and only touches the Digilent cable with the Arty's serial.
* `proj150.srcs/sim_1` (`sim_tb_top.v`, Micron DDR3 model) belongs to the old project's xsim simulation and is
  not wired into the Makefile; use `make sim`.
* The project-mode files (`proj150.xpr`, the `.xci`/`.xml` IP files, `scripts/build.tcl`) are gone; they
  are in git history before the `make-build` change.
