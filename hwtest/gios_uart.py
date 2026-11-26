#!/usr/bin/env python3
"""gios_uart.py - drive the GIOS BIOS prompt over the Arty's USB-UART non-interactively and log it.

  gios_uart.py [--port P] [--log FILE] [--wait-banner S] [--file ADDR HEXFILE] CMD ...

Each CMD is typed one character at a time (GIOS polls the UART; no RX FIFO), terminated with CR,
and the reply is collected until the next "> " prompt (or a timeout). "@sleep N" pauses N seconds.
--file ADDR HEXFILE sends "file ADDR NBYTES" followed by the 8-hex-digit words (like
cs150-1245/scripts/hex_to_serial.py), before the commands. Everything received is logged.
"""
import argparse, sys, time
import serial

ARTY = "/dev/serial/by-id/usb-Digilent_Digilent_USB_Device_210319BCC332-if01-port0"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default=ARTY)
    ap.add_argument("--log", default=None)
    ap.add_argument("--wait-banner", type=float, default=0.0, help="seconds to listen before typing")
    ap.add_argument("--timeout", type=float, default=8.0, help="per-command prompt timeout (s)")
    ap.add_argument("--char-delay", type=float, default=0.004)
    ap.add_argument("--file", nargs=2, action="append", metavar=("ADDR", "HEXFILE"), default=[])
    ap.add_argument("cmds", nargs="*")
    a = ap.parse_args()
    if "ttyUSB2" in a.port or "FTDI" in a.port:
        sys.exit("refusing: that is the XUPV5 UART")
    log = open(a.log, "a") if a.log else None
    ser = serial.Serial(a.port, 115200, timeout=0.05)

    def out(s):
        sys.stdout.write(s); sys.stdout.flush()
        if log: log.write(s); log.flush()

    def drain(t_end, until=None):
        buf = ""
        while time.time() < t_end:
            d = ser.read(4096).decode("latin-1")
            if d:
                out(d); buf += d
                if until and buf.endswith(until):
                    return buf, True
        return buf, False

    def typ(s):
        for ch in s:
            ser.write(ch.encode("latin-1")); time.sleep(a.char_delay)

    out("\n#### %s  port=%s\n" % (time.strftime("%Y-%m-%d %H:%M:%S %Z"), a.port))
    if a.wait_banner:
        drain(time.time() + a.wait_banner)
    typ("\r")
    drain(time.time() + 1.0, "> ")
    for addr, hexfile in a.file:
        words = [l.strip() for l in open(hexfile) if l.strip() and not l.startswith("@")]
        out("\n#### file %s %d (%d words from %s)\n" % (addr, 4 * len(words), len(words), hexfile))
        typ("file %s %d " % (addr, 4 * len(words)))
        for w in words:
            assert len(w) == 8, w
            typ(w)
        drain(time.time() + a.timeout, "> ")
    for c in a.cmds:
        if c.startswith("@sleep"):
            time.sleep(float(c.split()[1])); drain(time.time() + 0.2); continue
        typ(c + "\r")
        _, ok = drain(time.time() + a.timeout, "> ")
        if not ok:
            out("\n#### TIMEOUT waiting for prompt after: %s\n" % c)
    drain(time.time() + 0.3)
    out("\n#### done\n")

if __name__ == "__main__":
    main()
