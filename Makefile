# Makefile - non-project Vivado build of proj150 (MIPS150 + DDR3 + VGA/GPU). No .xpr, no Vivado GUI.
# In the spirit of the cs150 ISE flow (hardware/Makefile): make synth / impl / bit / timing / program.
#
#   make ip                  generate the IP cores (MIG, MMCM, FIFOs, BRAMs) from ip/*.tcl, boards/*/ip/*.tcl
#   make synth               synthesize                      -> build/arty/synth/post_synth.dcp
#   make impl                place and route, check timing   -> build/arty/impl/post_route.dcp
#   make bit                 bitstream (the default 'all' also prints the timing summary)
#   make timing              WNS/WHS and utilization of the routed design
#   make program             load the bitstream into the Arty over its Digilent cable (never the XUPV5)
#   make mmi                 memory map of the four block RAMs (bios, dmem, imem, isr) from the routed design,
#                            INIT contents checked against the IP images  -> build/arty/proj150_arty.mmi
#   make patch COE=sw/gios.inst.coe   swap one RAM image into the EXISTING bitstream with updatemem, no rebuild
#                            -> build/arty/proj150_arty_patched.bit;  patch-bios / patch-dmem / patch-imem /
#                            patch-isr patch the matching sw/ image (sw/MANIFEST: gios, bench, proj7, isr7)
#   make sim                 Icarus regression: sim/ise (ISE rig) + memory path + PixelFeeder + GPU (no Xilinx tools)
#   make sim-ise             only the ISE rig (sim/ise; 'make -C sim/ise list' for its tests)
#   make sw-import           copy the built BRAM images (sw/MANIFEST) from CS150; does not build software
#   make ise-diff            compare the RTL with the cs150-1245 ISE branch (FILE=cpu/StageF.v for one diff)
#   make clean               remove build/<board>;  make clean-impl keeps the generated IP
#
# Parameters (override on the command line):
#   BOARD=arty               board directory under boards/ (pynq-z2 is a placeholder)
#   SW_STALL_EN=0            ArtyA7top parameter: ignore SWITCH[1] (bring-up builds)
#   GENERICS="A=1 B=2"       any other top-level parameters (sticky: later runs without them reuse
#                            the last ones; 'GENERICS=' resets to the defaults)
#   TIMING_GATE=0            write the bitstream even if setup/hold slack is negative
#   IP_JOBS=4                Vivado instances to run in parallel when generating IP
#   VIVADO=/path/to/vivado   default: vivado from PATH, else /tools/Xilinx/Vivado/2019.1/bin/vivado
#   HW_SERIAL=...            Digilent cable serial for 'make program' (default: boards/<board>/board.mk)
#   CS150=../cs150-1245      checkout of the ISE branch (software built there), for sw-import and ise-diff
#   COE=sw/x.coe MEM=bios    make patch: image to load; MEM (bios|dmem|imem|isr) only when the file name is not one of sw/MANIFEST
#   PATCH_IN=a.bit PATCH_OUT=b.bit   make patch: input/output bitstream (default build/arty/proj150_arty{,_patched}.bit);
#                            chain patches:  make patch-bios PATCH_OUT=t.bit; make patch-dmem PATCH_IN=t.bit
#   PATCH_FORCE=1            make patch: allow a bitstream older than post_route.dcp
#   MMI_VERIFY=0             make mmi: skip the INIT check (assumes ramloop[k] = bit slice k; unsafe)
#
# Caveats of make patch: it never rebuilds, so 'make bit' must have run. The result is a TEST ARTIFACT: the IP, the
# checkpoints and the Makefile's tracking still hold the old image (the next make bit rebuilds from sw/, not from the
# patch). The MMI records block RAM placement, so patch only a bitstream written from the SAME routed checkpoint
# the MMI was made from (make mmi regenerates it when post_route.dcp is newer). Each RAM is fixed at 4096 words
# (PATCH_DEPTH): a shorter image is zero-padded, a longer one is an error - that needs a full rebuild.

BOARD ?= arty
include boards/$(BOARD)/board.mk

VIVADO      ?= $(shell command -v vivado 2>/dev/null || echo /tools/Xilinx/Vivado/2019.1/bin/vivado)
IP_JOBS     ?= 4
TIMING_GATE ?= 1

OUT   := build/$(BOARD)
SRC1  := proj150.srcs/sources_1
# Top-level parameters are sticky: given on the command line they are stored in build/<board>/synth.params
# and reused by later runs without them, so 'make timing' after 'make bit SW_STALL_EN=0' reports on that
# build instead of rebuilding with the defaults. 'make bit GENERICS=' goes back to the defaults.
ifeq ($(origin SW_STALL_EN)$(origin GENERICS),undefinedundefined)
GEN_ALL := $(strip $(shell cat $(OUT)/synth.params 2>/dev/null))
else
GEN_ALL := $(strip $(GENERICS) $(if $(SW_STALL_EN),SW_STALL_EN=$(SW_STALL_EN)))
endif
ifneq ($(GEN_ALL),)
$(info top-level parameters: $(GEN_ALL))
endif

# RTL the synthesis reads (scripts/sources.tcl lists the files; any .v/.vh edit retriggers synth)
RTL := $(shell find $(SRC1)/imports/src -type f \( -name '*.v' -o -name '*.vh' \)) scripts/sources.tcl

# COE files that initialise the block RAM IP: local copies of images built in cs150-1245 (make sw-import)
IP_DEPS_bios_mem     := sw/gios.inst.coe
IP_DEPS_dmem_blk_ram := sw/bench.inst.coe
IP_DEPS_imem_blk_ram := sw/proj7.inst.coe
IP_DEPS_isr_mem      := sw/isr7.coe

IP_DCP      := $(foreach i,$(IPS),$(OUT)/ip/$(i)/$(i).dcp)
ip_script    = $(firstword $(wildcard boards/$(BOARD)/ip/$(1).tcl ip/$(1).tcl))
COMMON_TCL  := scripts/common.tcl boards/$(BOARD)/board.mk

# Run a Vivado stage in its own scratch directory (so parallel runs do not share .Xil/ or journals)
# $(1) stage name, $(2) script, $(3) extra tclargs
VIVADO_ARGS = BOARD=$(BOARD) PART=$(PART) TOP=$(TOP) BUILD=$(CURDIR)/$(OUT) BIT=$(BIT) TIMING_GATE=$(TIMING_GATE)
define vivado_run
	@mkdir -p $(OUT)/logs $(OUT)/tmp/$(1)
	cd $(OUT)/tmp/$(1) && $(VIVADO) -mode batch -notrace -nojournal -log $(CURDIR)/$(OUT)/logs/$(1).log \
	    -source $(CURDIR)/scripts/$(2) -tclargs $(VIVADO_ARGS) $(3)
endef

.DEFAULT_GOAL := all
CS150 ?= ../cs150-1245

.PHONY: all ip synth impl bit timing program mmi patch patch-bios patch-dmem patch-imem patch-isr sim sim-ise sw-import ise-diff clean clean-impl clean-ip help FORCE

all: bit timing

help:
	@sed -n '2,/^$$/p' Makefile | sed 's/^# \{0,1\}//'

# ----------------------------------------------------------------------------------------- IP
# One Vivado per IP; re-run only when that IP's Tcl (or the files it reads) changed.
define ip_rule
$(OUT)/ip/$(1)/$(1).dcp: $(call ip_script,$(1)) $(IP_DEPS_$(1)) scripts/ip.tcl $(COMMON_TCL)
	$$(call vivado_run,ip_$(1),ip.tcl,IP=$(1))
endef
$(foreach i,$(IPS),$(eval $(call ip_rule,$(i))))

ip:
	@$(MAKE) --no-print-directory -j$(IP_JOBS) $(IP_DCP)

# ----------------------------------------------------------------------------------------- synth
# A parameter change (e.g. SW_STALL_EN=0 -> 1) must rebuild: keep them in a file that only changes then
$(OUT)/synth.params: FORCE
	@mkdir -p $(OUT)
	@echo '$(GEN_ALL)' | cmp -s - $@ || echo '$(GEN_ALL)' > $@

$(OUT)/synth/post_synth.dcp: $(IP_DCP) $(RTL) $(XDC) $(OUT)/synth.params scripts/synth.tcl $(COMMON_TCL)
	$(call vivado_run,synth,synth.tcl,XDC=$(XDC) IPS="$(IPS)" GENERICS="$(GEN_ALL)")

synth: $(OUT)/synth/post_synth.dcp

# ----------------------------------------------------------------------------------------- impl
$(OUT)/impl/post_route.dcp: $(OUT)/synth/post_synth.dcp scripts/impl.tcl scripts/common.tcl
	$(call vivado_run,impl,impl.tcl)

impl: $(OUT)/impl/post_route.dcp

# ----------------------------------------------------------------------------------------- bit
$(OUT)/$(BIT): $(OUT)/impl/post_route.dcp scripts/bit.tcl scripts/common.tcl
	$(call vivado_run,bit,bit.tcl)

bit: $(OUT)/$(BIT)

timing: $(OUT)/impl/post_route.dcp
	$(call vivado_run,timing,timing.tcl)
	@cat $(OUT)/timing.txt

# ----------------------------------------------------------------------------------------- program
# Only a Digilent target is ever opened (scripts/program.tcl); HW_SERIAL pins the Arty's cable.
program: $(OUT)/$(BIT)
	@mkdir -p $(OUT)/logs $(OUT)/tmp/program
	cd $(OUT)/tmp/program && $(VIVADO) -mode batch -notrace -nojournal -log $(CURDIR)/$(OUT)/logs/program.log \
	    -source $(CURDIR)/scripts/program.tcl -tclargs $(CURDIR)/$(OUT)/$(BIT) $(HW_SERIAL) $(HW_URL) $(HW_DEVICE)

# ----------------------------------------------------------------------------------------- mmi, patch
# updatemem swaps the contents of block RAMs inside a finished bitstream (the Vivado successor of ISE's data2mem
# / bitgen -g UpdtBRAM): seconds instead of a rebuild. It needs a .mmi memory map of the RAMs; scripts/mmi.tcl
# writes one from the routed checkpoint and checks it against the IP images. These targets never rebuild
# anything: they do not depend on post_route.dcp or the bitstream, they only check that they exist.
MMI          := $(OUT)/$(BIT:.bit=.mmi)
PATCH_DEPTH  ?= 4096
PATCH_IN     ?= $(OUT)/$(BIT)
PATCH_OUT    ?= $(OUT)/$(BIT:.bit=_patched.bit)
UPDATEMEM    ?= $(dir $(VIVADO))updatemem
TCLSH        ?= $(shell command -v tclsh 2>/dev/null)
# memory name (the -proc name in the MMI) : IP name; the image of each is IP_DEPS_<ip>
PATCH_MEMS   := bios:bios_mem dmem:dmem_blk_ram imem:imem_blk_ram isr:isr_mem
# MEM from the file name of COE unless given
MEM          ?= $(strip $(foreach p,$(PATCH_MEMS),$(if $(filter $(notdir $(COE)),$(notdir $(IP_DEPS_$(word 2,$(subst :, ,$(p)))))),$(word 1,$(subst :, ,$(p))))))

$(MMI): scripts/mmi.tcl scripts/coe.tcl $(COMMON_TCL)
	$(call vivado_run,mmi,mmi.tcl,DEPTH=$(PATCH_DEPTH) $(if $(MMI_VERIFY),MMI_VERIFY=$(MMI_VERIFY)))
	@cat $(OUT)/reports/mmi_verify.rpt

# Regenerated when post_route.dcp is newer (or MMI_VERIFY is given). Done by removing the stale file, so
# post_route.dcp is not a prerequisite and 'make mmi' can never start a synthesis or implementation.
mmi:
	@test -f $(OUT)/impl/post_route.dcp || { echo "make mmi: no routed checkpoint $(OUT)/impl/post_route.dcp: run 'make impl' first"; exit 1; }
	@if [ $(OUT)/impl/post_route.dcp -nt $(MMI) $(if $(MMI_VERIFY),|| true) ]; then rm -f $(MMI); fi
	@$(MAKE) --no-print-directory $(MMI)
	@echo "$(MMI) is up to date with $(OUT)/impl/post_route.dcp"

patch:
	@test -n "$(COE)" || { echo "usage: make patch COE=sw/gios.inst.coe   (or patch-bios / patch-dmem / patch-imem / patch-isr)"; exit 1; }
	@test -f "$(COE)" || { echo "make patch: $(COE) does not exist"; exit 1; }
	@test -n "$(filter bios dmem imem isr,$(MEM))" || { echo "make patch: cannot tell which RAM $(COE) is for: add MEM=bios|dmem|imem|isr (sw/MANIFEST names: $(foreach p,$(PATCH_MEMS),$(notdir $(IP_DEPS_$(word 2,$(subst :, ,$(p)))))))"; exit 1; }
	@test -f "$(PATCH_IN)" || { echo "make patch: $(PATCH_IN) does not exist: run 'make bit' first (patching never rebuilds)"; exit 1; }
	@test -f $(OUT)/impl/post_route.dcp || { echo "make patch: no routed checkpoint $(OUT)/impl/post_route.dcp to take the RAM locations from: run 'make impl'"; exit 1; }
	@if [ $(OUT)/impl/post_route.dcp -nt "$(PATCH_IN)" ] && [ -z "$(PATCH_FORCE)" ]; then \
	    echo "make patch: $(PATCH_IN) is older than $(OUT)/impl/post_route.dcp, so the RAM locations in the MMI may not match it."; \
	    echo "            Run 'make bit', or PATCH_FORCE=1 if you know it was written from this checkpoint."; exit 1; fi
	@test "$(abspath $(PATCH_IN))" != "$(abspath $(PATCH_OUT))" || { echo "make patch: PATCH_IN and PATCH_OUT are the same file"; exit 1; }
	@$(MAKE) --no-print-directory mmi
	@mkdir -p $(OUT)/patch $(OUT)/logs $(OUT)/tmp/patch
	$(if $(TCLSH),$(TCLSH) scripts/coe2mem.tcl $(COE) $(OUT)/patch/$(MEM).mem DEPTH=$(PATCH_DEPTH),\
	    cd $(OUT)/tmp/patch && $(VIVADO) -mode batch -notrace -nojournal -log $(CURDIR)/$(OUT)/logs/coe2mem.log \
	    -source $(CURDIR)/scripts/coe2mem.tcl -tclargs $(abspath $(COE)) $(CURDIR)/$(OUT)/patch/$(MEM).mem DEPTH=$(PATCH_DEPTH))
	cd $(OUT)/tmp/patch && $(UPDATEMEM) -meminfo $(CURDIR)/$(MMI) -data $(CURDIR)/$(OUT)/patch/$(MEM).mem -proc $(MEM) \
	    -bit $(abspath $(PATCH_IN)) -out $(abspath $(PATCH_OUT)) -force > $(CURDIR)/$(OUT)/logs/patch.log 2>&1; \
	    rc=$$?; cat $(CURDIR)/$(OUT)/logs/patch.log; exit $$rc
	@echo "patched $(MEM) of $(PATCH_IN) with $(COE) -> $(PATCH_OUT)"
	@echo "TEST ARTIFACT: the IP/checkpoints still hold the old image; load it with scripts/program.tcl (see 'make program')"

patch-bios: ; @$(MAKE) --no-print-directory patch MEM=bios COE=$(or $(COE),$(IP_DEPS_bios_mem))
patch-dmem: ; @$(MAKE) --no-print-directory patch MEM=dmem COE=$(or $(COE),$(IP_DEPS_dmem_blk_ram))
patch-imem: ; @$(MAKE) --no-print-directory patch MEM=imem COE=$(or $(COE),$(IP_DEPS_imem_blk_ram))
patch-isr:  ; @$(MAKE) --no-print-directory patch MEM=isr  COE=$(or $(COE),$(IP_DEPS_isr_mem))

# ----------------------------------------------------------------------------------------- sim
sim: sim-ise
	sim/icarus/run_icarus.sh

# The cs150-1245 ISE Icarus rig (sim/ise, see its README): unit/CPU/GPU tests carried over from ISE
sim-ise:
	$(MAKE) -C sim/ise all CS150=$(abspath $(CS150))

# ----------------------------------------------------------------------------------------- sw-import
sw-import:
	scripts/sw-import.sh $(CS150)

# ----------------------------------------------------------------------------------------- ise-diff
# Review aid for the ISE port (normalised: comments/whitespace/default_nettype ignored). RAW=1 for plain diffs.
ise-diff:
	scripts/tools/ise_diff.py --cs150 $(CS150) $(if $(RAW),--raw) $(FILE)

# ----------------------------------------------------------------------------------------- clean
clean:
	rm -rf $(OUT)

clean-impl:
	rm -rf $(OUT)/synth $(OUT)/impl $(OUT)/reports $(OUT)/tmp $(OUT)/$(BIT) $(OUT)/timing.txt $(OUT)/synth.params \
	    $(MMI) $(OUT)/patch $(OUT)/$(BIT:.bit=_patched.bit)

clean-ip:
	rm -rf $(OUT)/ip
