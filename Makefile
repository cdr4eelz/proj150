# Makefile - non-project Vivado build of proj150 (MIPS150 + DDR3 + VGA/GPU). No .xpr, no Vivado GUI.
# In the spirit of the cs150 ISE flow (hardware/Makefile): make synth / impl / bit / timing / program.
#
#   make ip                  generate the IP cores (MIG, MMCM, FIFOs, BRAMs) from ip/*.tcl, boards/*/ip/*.tcl
#   make synth               synthesize                      -> build/arty/synth/post_synth.dcp
#   make impl                place and route, check timing   -> build/arty/impl/post_route.dcp
#   make bit                 bitstream (the default 'all' also prints the timing summary)
#   make timing              WNS/WHS and utilization of the routed design
#   make program             load the bitstream into the Arty over its Digilent cable (never the XUPV5)
#   make sim                 Icarus regression of memory path + PixelFeeder + GPU (no Xilinx tools)
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
#   CS150=../cs150-1245      checkout of the ISE branch, for ise-diff

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

# COE files that initialise the block RAM IP
IP_DEPS_bios_mem     := $(SRC1)/imports/gios/gios.inst.coe
IP_DEPS_dmem_blk_mem := $(SRC1)/imports/testdata/testdata.coe
IP_DEPS_imem_blk_mem := $(SRC1)/imports/software/simplesend/simplesend.inst.coe
IP_DEPS_isr_mem      := $(SRC1)/imports/isr/basic.coe

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

.PHONY: all ip synth impl bit timing program sim ise-diff clean clean-impl clean-ip help FORCE

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

# ----------------------------------------------------------------------------------------- sim
sim:
	sim/icarus/run_icarus.sh

# ----------------------------------------------------------------------------------------- ise-diff
# Review aid for the ISE port (normalised: comments/whitespace/default_nettype ignored). RAW=1 for plain diffs.
ise-diff:
	scripts/tools/ise_diff.py --cs150 $(CS150) $(if $(RAW),--raw) $(FILE)

# ----------------------------------------------------------------------------------------- clean
clean:
	rm -rf $(OUT)

clean-impl:
	rm -rf $(OUT)/synth $(OUT)/impl $(OUT)/reports $(OUT)/tmp $(OUT)/$(BIT) $(OUT)/timing.txt $(OUT)/synth.params

clean-ip:
	rm -rf $(OUT)/ip
