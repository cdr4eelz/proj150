# Arty A7-100 hardware run, branch ellipse-fix (RTL = commit bfe60bf), 2026-11-25 (America/Los_Angeles)

Bitstream: build/proj150_arty.bit md5 92e8a177b3ad6e36ef0cdd75dc2ac8c4, Vivado 2019.1, SW_STALL_EN=0,
timing met (WNS 0.408 ns, WHS 0.017 ns). Programmed on xilinx_tcf/Digilent/210319BCC332A only; UART
usb-Digilent_Digilent_USB_Device_210319BCC332-if01-port0 @115200. The XUPV5 was not touched.

| stage | result |
|---|---|
| gpu | hwfill ff8040 reads ff8040 at 3 points (row 0 x=0, x=799, last row); pixel 800 of the row is uninitialised padding. hwline 0 0 799 599 reads 000000ff at both ends. hwelip 400 300 200 150 (00ff00) reads 0000ff00 at (200,300)-side and bottom points; gs after: `GF#01-ELFG` (all units ready, upper case) |
| dcache | copy checksums ac408670 (x5); byte/half lw c981f982 18181818 10101010 ffffcfef c981c9c2 c0ffee14 11aa3344 ffffbbcc |
| icache | copy 40000000 -> 5be7a569 (3 ways); lw 10020000 = 00000020 twice |
| pixfeed, pixfeed_stress | no fault flag, underrun clear |
| elip (5 ellipses) | 134/134 lw reads match the model (incl. 30 points of the circle (600,100,r50), all 0000ffff = cyan); 0 of 547 hardware row XOR checksums differ from the model; GF busy flag clear after every hwelip |
| elipbig (399x299, ff8000) | 36/36 lw good; 0 of 600 rows differ from the model and from the CPU swelip frame |

Note: for the 5-ellipse set the CPU `swelip 700 520 60 40` reference frame has a stray magenta pixel
at (108,0) (and in 323 other rows' low columns); the hardware frame does not. The hardware check therefore
compares each row with the XOR computed from the model; the software frame is reported as info only.
