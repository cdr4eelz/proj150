#!/bin/bash
# run_stages.sh STAGE - GIOS command sequences for the ddr-fix bring-up (UART log in hwtest/logs/).
#   banner | dcache | icache | pixfeed | pixfeed_stress | pixfeed_isolate | gpu | elip | elipbig
#   LOGPFX=after_ ./run_stages.sh gpu   writes logs/after_gpu.log
set -u; cd "$(dirname "$0")"; mkdir -p logs
G="python3 ./gios_uart.py --log logs/${LOGPFX:-}$1.log"
case "$1" in
  banner)  $G --wait-banner 3 help gs ;;
  dcache)
    $G --timeout 60 --file 10100000 data4k.hex \
       result "copy 10100000 0 1000" "copy 10100000 10180000 1000" "copy 10180000 0 1000" \
       "copy 10100000 10104000 1000" "copy 10104000 0 1000" \
       "dump 10100000" "dump 10180000" \
       "sw 18181818 18000040" "sw 10101010 10000040" "lw 10002040" "lw 18000040" "lw 10000040" \
       "sw c0ffee14 10001014" "lw 10003014" "lw 10001000" "lw 10001014" \
       "sw 11223344 10001100" "sb aa 10001101" "sh bbcc 10001106" "lw 10001100" "lw 10001104" "lhu 10001102" "lbu 10001103" \
       "copy 40000000 10200000 4000" "copy 40000000 0 4000" "copy 10200000 0 4000" ;;
  icache)
    $G --timeout 30 --file 10030000 icache_prog.hex "sw 0 10020000" result "jal 10030000" "lw 10020000" \
       "jal 10030000" "lw 10020000" ;;
  pixfeed)
    $G --timeout 30 gs "pf 1" "@sleep 1" gs "@sleep 2" gs "pf 0" "@sleep 1" gs "pf 1" "@sleep 1" gs ;;
  pixfeed_stress)
    # display (frame 1) while the CPU streams write-through stores (swfill) and the caches run:
    # the underrun flag (D in gs, '*' = pf_fault) must stay clear after everything.
    $G --timeout 60 --file 10110000 data4k.hex gs "pf 1" result "copy 10110000 0 1000" "copy 10110000 10190000 1000" \
       "copy 10190000 0 1000" "copy 40000000 10210000 4000" "copy 10210000 0 4000" "sf 1" "swcolor 00203040" "swfill" \
       "lw 10400000" "lw 10657c7c" gs "copy 10100000 0 1000" "copy 10200000 0 4000" gs ;;
  pixfeed_isolate)
    # PixelFeeder alone, then a copy burst, then a frame-2 software fill (CPU store stream only)
    $G --timeout 30 gs "pf 1" gs "copy 40000000 10210000 4000" "copy 10210000 10250000 4000" "copy 10250000 0 4000" gs \
       "sf 2" "swcolor 00ff0000" "swfill" gs ;;
  gpu)
    # PixelFeeder shows frame 1 while the GPU writes it; pf_fault ('*' in gs) must stay clear.
    # hwelip must finish: the second and third 'gs' show GF#..-ELFG (all upper case = every unit ready).
    $G --timeout 60 gs "pf 1" "gf 1" "hwcolor 00ff8040" "hwfill" "@sleep 1" gs "lw 10400000" "lw 10400c7c" "lw 10657c7c" \
       "lw 10400c80" "hwcolor 000000ff" "hwline 0 0 799 599" "@sleep 1" gs "lw 10400000" "lw 1052c640" "lw 1052c644" \
       "hwcolor 0000ff00" "hwelip 400 300 200 150" "@sleep 3" gs "lw 10496640" "lw 105c2640" "@sleep 5" gs ;;
  elip|elipbig)
    # GPU ellipses (frame 1, hwelip) against the CPU swelip reference (frame 2): pixel reads at model
    # points + band checksums; prints PASS/FAIL. elipbig = the 399x299 ellipse alone.
    BIGARG=""; [ "$1" = elipbig ] && BIGARG="--big"
    mapfile -t C < <(python3 elip_check.py cmds $BIGARG)
    $G --timeout 90 "${C[@]}"
    python3 elip_check.py check logs/${LOGPFX:-}$1.log $BIGARG ;;
  *) echo "usage: $0 banner|dcache|icache|pixfeed|pixfeed_stress|pixfeed_isolate|gpu|elip|elipbig"; exit 2 ;;
esac
