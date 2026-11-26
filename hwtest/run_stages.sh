#!/bin/bash
# run_stages.sh STAGE - GIOS command sequences for the ddr-fix bring-up (UART log in hwtest/logs/).
#   dcache | icache | pixfeed | gpu
set -u; cd "$(dirname "$0")"; mkdir -p logs
G="python3 ./gios_uart.py --log logs/$1.log"
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
  gpu)
    $G --timeout 60 gs "gf 1" "hwcolor 00ff8040" "hwfill" "@sleep 1" gs "lw 10400000" "lw 10400c7c" "lw 10657c7c" \
       "hwcolor 000000ff" "hwline 0 0 799 599" "@sleep 1" gs "lw 10400000" "lw 10401004" ;;
  *) echo "usage: $0 banner|dcache|icache|pixfeed|gpu"; exit 2 ;;
esac
