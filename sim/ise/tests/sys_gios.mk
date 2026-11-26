# Whole MIPS150 booting proj150's own default images straight from sw/ (no software build): the GIOS
# BIOS (sw/gios.inst.coe), isr7, bench (X5) and proj7 (X6), as the bitstream does. Exercises lw/lhu/lbu/sw
# on X5/X6, code stored to X5 and run with jal (X5 port-B fetch), HaltVal at 0x80000084, rnd, gs.
# Golden transcript: tb/data/sys/gios.golden ('~' = any byte: PRNG and status values)
sys_gios.TOP      := SysUART_tb
sys_gios.TB       := tb/SysUART_tb.v
sys_gios.SRCS     := tb/models/brams.v tb/models/uarx_fifo.v $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v
sys_gios.INCS     := $(SRC)
sys_gios.YDIRS    := $(SRC_YDIRS)
sys_gios.SW_BIOS  := gios.inst.coe
sys_gios.RUNFILES := tb/data/sys/gios.in tb/data/sys/gios.golden
sys_gios.PLUSARGS := +in=gios.in +golden=gios.golden +max_cycles=3000000
sys_gios.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator
