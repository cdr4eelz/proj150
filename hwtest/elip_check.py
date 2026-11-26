#!/usr/bin/env python3
"""elip_check.py - hardware check of the GPU ellipse engine against a model of the ISE swelip algorithm.

  elip_check.py cmds            print the GIOS commands (one per line) that draw the ellipses with the
                                GPU (hwelip, frame 1) and with the CPU (swelip, frame 2) and read back
  elip_check.py check LOGFILE   parse the UART log of those commands and print PASS/FAIL lines

Frame 1 = hardware (gf 1), frame 2 = software reference (sf 2). Both frames are first filled with the
same background. Reads: every Nth model pixel and the extremes with `lw`, a few background pixels, and
the XOR checksum (`copy ADDR 0 LEN`, as the D$ test uses) of 4-row bands of both frames, which must be
equal band by band. The ellipses must fit on screen (the engine does not clip).
"""
import re, sys

BG = 0x00102030
ELIPS = [  # xc, yc, a, b, colour
    (400, 300, 200, 150, 0x0000ff00),
    (100,  80,  30,  60, 0x00ffff00),
    (700, 520,  60,  40, 0x00ff00ff),
    (600, 100,  50,  50, 0x0000ffff),
    (300, 550,   3,   2, 0x00ffffff),
]
BIG = (400, 300, 399, 299, 0x00ff8000)   # run last, on its own: AABB overflows 32 bits
FRAME_HW, FRAME_SW = 0x10400000, 0x10800000
STRIDE = 0x1000                          # 4096 bytes per row

def model(xc, yc, a, b):
    """The swelip loops in exact integer arithmetic; returns the set of (x,y) pixels."""
    pts = set()
    def plot(x, y):
        for sx in (-x, x):
            for sy in (-y, y):
                pts.add((xc + sx, yc + sy))
    AA, BB = a * a, b * b
    AABB = AA * BB
    x, y = 0, b
    AAy, BBx, BB2xp3 = AA * b, 0, 3 * BB
    stopper = (AA >> 1) + BB
    dd = BB - AA * b + (AA >> 2)
    plot(x, y)
    while y > 0 and x <= a and AAy - BBx > stopper:
        if dd >= 0:
            dd += 2 * AA - 2 * AAy; y -= 1; AAy -= AA
        dd += BB2xp3; x += 1; BBx += BB; BB2xp3 += 2 * BB
        plot(x, y)
    BB2xp2 = BB2xp3 - BB
    dd = BB * (x * x + x) + (BB >> 2) + AA * (y - 1) ** 2 - AABB
    while y > 0:
        if dd < 0:
            dd += BB2xp2; x += 1; BB2xp2 += 2 * BB
        dd += 3 * AA - 2 * AAy; y -= 1; AAy -= AA
        plot(x, y)
    return pts

def addr(frame, x, y): return frame + y * STRIDE + 4 * x

def plan(big=False):
    """-> (commands, expected {addr: value} for lw, band list [(offset, len)])"""
    cmds, lw, bands = [], {}, []
    cmds += ["pf 1", "gf 1", "sf 2", "hwcolor %08x" % BG, "hwfill", "swcolor %08x" % BG, "swfill", "gs"]
    ellipses = [BIG] if big else ELIPS
    pix_all = {}
    for (xc, yc, a, b, col) in ellipses:
        cmds += ["hwcolor %08x" % col, "hwelip %d %d %d %d" % (xc, yc, a, b), "@sleep 1", "gs"]
        cmds += ["swcolor %08x" % col, "swelip %d %d %d %d" % (xc, yc, a, b)]
        pts = sorted(model(xc, yc, a, b))
        for p in pts: pix_all[p] = col
        sel = pts[::max(1, len(pts) // 24)]
        ext = [(xc - a, yc), (xc + a, yc), (xc, yc - b), (xc, yc + b)]
        for (x, y) in sel + [e for e in ext if e in pix_all]:
            lw[addr(FRAME_HW, x, y)] = col
    for (x, y) in [(0, 0), (799, 599), (400, 300), (13, 590), (790, 5), (250, 300), (555, 333)]:
        if (x, y) not in pix_all: lw[addr(FRAME_HW, x, y)] = BG
    for a_ in sorted(lw): cmds.append("lw %08x" % a_)
    ys = sorted({y for (_, y) in pix_all})
    y0, y1 = ys[0] & ~3, ys[-1] | 3
    rows = [y for y in range(0, 600, 4) if (y0 - 8 <= y <= y1 + 8) or y in (0, 596)]
    for r in rows:
        bands.append((r * STRIDE, 4 * STRIDE))
        cmds += ["copy %08x 0 %x" % (FRAME_HW + r * STRIDE, 4 * STRIDE), "copy %08x 0 %x" % (FRAME_SW + r * STRIDE, 4 * STRIDE)]
    cmds.append("gs")
    return cmds, lw, bands

def check(logfile, big=False):
    cmds, lw, bands = plan(big)
    text = open(logfile, errors="replace").read()
    # replies: "> <cmd>\n<reply...>" up to the next "> "
    chunks = re.split(r"\n> ", text)
    replies = []
    for c in chunks[1:]:
        head, _, rest = c.partition("\n")
        replies.append((head.strip(), rest.strip()))
    ok = True
    lwbad = lwgood = 0
    copies = []
    gs_after = []
    for head, rest in replies:
        m = re.match(r"lw ([0-9a-f]{8})$", head)
        if m:
            a_ = int(m.group(1), 16)
            mm = re.match(r"([0-9a-f]{8}): ([0-9a-f]{8})", rest)
            if a_ in lw:
                if mm and int(mm.group(2), 16) == lw[a_]: lwgood += 1
                else:
                    lwbad += 1; print("LW MISMATCH %08x: got %s expected %08x" % (a_, mm.group(2) if mm else rest[:20], lw[a_]))
        elif head.startswith("copy "):
            copies.append((head, rest.split()[0] if rest.split() else ""))
        elif head == "gs":
            gs_after.append(rest)
    pairs = list(zip(copies[0::2], copies[1::2]))
    bandbad = 0
    for ((h1, c1), (h2, c2)) in pairs:
        if c1 != c2 or not re.match(r"^[0-9a-f]{8}$", c1):
            bandbad += 1; print("BAND MISMATCH hw %s -> %s | sw %s -> %s" % (h1, c1, h2, c2))
    print("lw reads: %d good, %d bad (of %d expected)" % (lwgood, lwbad, len(lw)))
    print("bands: %d of %d hw/sw band checksums differ (%d copy replies)" % (bandbad, len(bands), len(copies)))
    # GF ready flag: after each hwelip the status line must show uppercase "ELFG"
    stat = [g.splitlines()[0] if g else "" for g in gs_after]
    notready = [s for s in stat if "GF#" in s and "ELFG" not in s]
    for s in stat: print("gs:", s)
    print("GF not ready in %d gs replies" % len(notready))
    good = lwbad == 0 and bandbad == 0 and lwgood == len(lw) and len(pairs) == len(bands) and not notready
    print("RESULT:", "PASS" if good else "FAIL")
    return 0 if good else 1

if __name__ == "__main__":
    big = "--big" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--big"]
    if args[0] == "cmds":
        print("\n".join(plan(big)[0]))
    elif args[0] == "check":
        sys.exit(check(args[1], big))
    else:
        sys.exit(__doc__)
