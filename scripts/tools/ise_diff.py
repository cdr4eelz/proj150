#!/usr/bin/env python3
"""ise_diff.py - compare proj150 RTL with the cs150-1245 ISE branch, for review of the ISE port.

  scripts/tools/ise_diff.py [--cs150 DIR] [--raw] [PATH ...]

With no PATH: one line per file (proj150 src vs ISE hardware/src, matched by relative path, with
the board-level renames below): SAME (byte identical), NORM (identical after normalising),
DIFF n (n normalised lines differ), ONLY-P150 / ONLY-ISE.
With PATH(s) (relative to the src root, e.g. cpu/StageF.v): print the unified diff, normalised
unless --raw.

Normalising only hides style that is not behaviour: comments, blank lines, whitespace,
`default_nettype/`timescale lines, spacing around [](),;:=, 'input wire'/'output wire'/'output reg' spacing, and SystemVerilog
'end : label' labels. It is a review aid: ported ISE files are kept verbatim, so a ported file
should report SAME.
"""
import argparse, difflib, os, re, sys

P150_SRC = 'proj150.srcs/sources_1/imports/src'
ISE_SRC = 'hardware/src'
# proj150 file -> ISE file where the board level differs by name
RENAMES = {'ArtyA7top.v': 'ml505top.v', 'MemoryDDR.v': 'Memory150.v'}
# ISE dirs that have no proj150 counterpart by design (CoreGen outputs, benches, ML505 DDR2 MIG)
SKIP_ISE_DIRS = ('core_ip', 'testbench', 'chipscope', 'base_mem/mig_v3_61')

def norm(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    out = []
    for line in text.splitlines():
        line = re.sub(r'//.*', '', line)
        if re.match(r'\s*`(default_nettype|timescale)\b', line):
            continue
        line = re.sub(r'\b(input|output|inout)\s+wire\b', r'\1', line)
        line = re.sub(r'\bend\s*:\s*\w+', 'end', line)
        line = re.sub(r'\s+', ' ', line).strip()
        line = re.sub(r'\s*([\[\](),;:=])\s*', r'\1', line)
        if line:
            out.append(line)
    return out

def files(root, skip=()):
    res = set()
    for d, dirs, fs in os.walk(root):
        rel = os.path.relpath(d, root)
        if any(rel == s or rel.startswith(s + os.sep) for s in skip):
            dirs[:] = []
            continue
        for f in fs:
            if f.endswith(('.v', '.vh', '.sv')):
                res.add(os.path.normpath(os.path.join(rel, f)))
    return res

def read(p):
    with open(p, errors='replace') as fh:
        return fh.read()

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--cs150', default=os.environ.get('CS150', '../cs150-1245'))
    ap.add_argument('--raw', action='store_true', help='diff the files as they are')
    ap.add_argument('--diff-only', action='store_true', help='summary: hide SAME/NORM lines')
    ap.add_argument('paths', nargs='*')
    a = ap.parse_args()
    top = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    psrc, isrc = os.path.join(top, P150_SRC), os.path.join(a.cs150, ISE_SRC)
    if not os.path.isdir(isrc):
        sys.exit(f'ise_diff: no {isrc} (set CS150=<cs150-1245 checkout>)')
    def ise_name(rel):
        return os.path.join(os.path.dirname(rel), RENAMES.get(os.path.basename(rel), os.path.basename(rel)))
    if a.paths:
        for rel in a.paths:
            pf, iff = os.path.join(psrc, rel), os.path.join(isrc, ise_name(rel))
            pt = read(pf).splitlines() if os.path.exists(pf) else []
            it = read(iff).splitlines() if os.path.exists(iff) else []
            if not a.raw:
                pt, it = norm('\n'.join(pt)), norm('\n'.join(it))
            sys.stdout.writelines(l + '\n' for l in difflib.unified_diff(
                it, pt, 'ise/' + ise_name(rel), 'proj150/' + rel, lineterm='', n=3))
        return
    pfs, ifs = files(psrc), files(isrc, SKIP_ISE_DIRS)
    seen_ise = set()
    for rel in sorted(pfs):
        iname = ise_name(rel)
        if iname not in ifs:
            print(f'ONLY-P150  {rel}')
            continue
        seen_ise.add(iname)
        pt, it = read(os.path.join(psrc, rel)), read(os.path.join(isrc, iname))
        if pt == it:
            st = 'SAME'
        else:
            pn, inn = norm(pt), norm(it)
            n = sum(1 for l in difflib.unified_diff(inn, pn, lineterm='', n=0)
                    if l[:1] in '+-' and not l.startswith(('+++', '---')))
            st = 'NORM' if n == 0 else f'DIFF {n}'
        if not (a.diff_only and st in ('SAME', 'NORM')):
            print(f'{st:<10} {rel}' + (f'  (ISE {iname})' if iname != rel else ''))
    for rel in sorted(ifs - seen_ise):
        print(f'ONLY-ISE   {rel}')

if __name__ == '__main__':
    main()
