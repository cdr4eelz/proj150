#!/usr/bin/env bash
# Icarus simulation of the real MemoryDDR + Cache + RequestController + PixelFeeder + GPU with a
# behavioral MIG UI (ui_mem_stub from arty-mig-test). No Xilinx libraries needed.
#   sim/icarus/run_icarus.sh [-DPF_TESTPAT=n] [-DRD_CREDIT=0|1] [-DPIXEL_PF_FULL=n ...] -- [plusargs]
# Without arguments: runs the regression list below.
set -euo pipefail
cd "$(dirname "$0")"
S=../../proj150.srcs/sources_1/imports/src
SRC=$(ls $S/MemoryDDR.v $S/base_mem/MigUiAdapter.v $S/base_mem/Cache.v $S/base_mem/RequestController.v \
         $S/base_mem/DDRStage.v $S/gpu/*.v)
mkdir -p out
build() {  # $1 = output name, rest = -D defines
    local o=$1; shift
    iverilog -g2012 -o out/$o.vvp -I $S -I $S/gpu -I $S/base_util "$@" tb_memddr.v models/*.v $SRC
}
run() {    # $1 = vvp name, $2 = label, rest = plusargs
    local o=$1 l=$2; shift 2
    echo "=== $l: $*"
    vvp -n out/$o.vvp "$@" > out/$l.log 2>&1 || true
    grep -aE 'MISMATCH|OVERFLOW|TIMEOUT|PROTOCOL|video_fault|SUMMARY|RESULT' out/$l.log | head -24
}
if [ $# -gt 0 ]; then
    defs=(); while [ $# -gt 0 ] && [ "$1" != "--" ]; do defs+=("$1"); shift; done; [ $# -gt 0 ] && shift
    build custom "${defs[@]}"; run custom custom "$@"; exit 0
fi
build dut -DPF_TESTPAT=0 -DRD_CREDIT=1 -DPIXEL_PF_FULL=448 -DPIXEL_PF_EMPTY=1600
fail=0
chk() { grep -aq "RESULT: PASS" out/$1.log && [ "$2" = pass ] || { grep -aq "RESULT: FAIL" out/$1.log && [ "$2" = fail ]; } || { echo "  ^^^ UNEXPECTED (wanted $2)"; fail=1; }; }
run dut d_only          +PF=0                      ; chk d_only pass
run dut pf_fullrate     +PF=1                      ; chk pf_fullrate pass
run dut pf_rdy30        +PF=1 +RDY_PCT=30          ; chk pf_rdy30 pass
run dut pf_rdy100       +PF=1 +RDY_PCT=100 +SEED=7 ; chk pf_rdy100 pass
run dut inject1_bitflip +PF=0 +INJECT=1 +INJECT_ADDR=1230 +INJECT_BIT=21 ; chk inject1_bitflip fail
run dut inject2_alias   +PF=1 +INJECT=2            ; chk inject2_alias fail
run dut inject3_nomask  +PF=0 +INJECT=3            ; chk inject3_nomask fail
if [ $fail = 0 ]; then echo "ALL ICARUS TESTS AS EXPECTED"; else echo "SOME ICARUS TESTS UNEXPECTED"; exit 1; fi
