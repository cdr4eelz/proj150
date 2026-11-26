#!/usr/bin/env bash
# Re-run the harness on the UNTOUCHED proj150 master RTL (eee4d5d: MIGAdapter for the 2:1 / 64-bit
# MIG, original Cache / RequestController / PixelFeeder), with models_legacy/ standing in for the
# 2:1 MIG. Only change to the old sources: leading '_' in literals (32'h_0000) that Icarus rejects.
#   sim/icarus/run_before.sh            -> results/before_*.log
set -euo pipefail
cd "$(dirname "$0")"
REF=${REF:-eee4d5d}
W=out/before_src
rm -rf $W; mkdir -p $W
git -C ../.. archive $REF proj150.srcs/sources_1/imports/src | tar -x -C $W
S=$W/proj150.srcs/sources_1/imports/src
sed -i "s/'h_/'h/g; s/'b_/'b/g" $S/base_mem/Cache.v
SRC=$(ls $S/MemoryDDR.v $S/base_mem/MIGAdapter.v $S/base_mem/Cache.v $S/base_mem/RequestController.v \
         $S/base_mem/DDRStage.v $S/gpu/*.v)
MODELS="models/ui_mem_stub.v models/fifo_async_fwft_model.v models/ip_fifos.v models/cache_brams.v models_legacy/mig_arty_a7_100.v"
mkdir -p results
for tp in 1 0; do
    iverilog -g2012 -o out/before_tp$tp.vvp -I $S -I $S/gpu -I $S/base_util -DLEGACY -DPF_TESTPAT=$tp tb_memddr.v $MODELS $SRC
done
run() { local v=$1 l=$2; shift 2; echo "=== $l: $*"; vvp -n out/$v.vvp "$@" > results/$l.log 2>&1 || true
        grep -aE 'reset released|P[123] done|SUMMARY|RESULT' results/$l.log; }
run before_tp1 before_A_eee4d5d_pixelfeeder_testpattern +PF=0      # as committed (COLT45_TESTPAT 1)
run before_tp0 before_B_eee4d5d_pixelfeeder_ddr        +PF=1      # PixelFeeder reading DDR (TESTPAT 0)
