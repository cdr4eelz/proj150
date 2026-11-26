#!/usr/bin/env bash
# sw-import.sh - copy the built MIPS images listed in sw/MANIFEST from a cs150-1245 checkout into sw/.
# Does not build anything: build the software in cs150-1245 first (cd <cs150>/software && make).
#   scripts/sw-import.sh [<cs150-1245 dir>]      (default ../cs150-1245; 'make sw-import CS150=...')
set -euo pipefail
top=$(cd "$(dirname "$0")/.." && pwd)
cs150=${1:-$top/../cs150-1245}
src=$cs150/software
[ -d "$src" ] || { echo "sw-import: no $src (CS150=<cs150-1245 checkout>)" >&2; exit 1; }
rev=$(git -C "$cs150" describe --always --dirty 2>/dev/null || echo unknown)
n=0; miss=0
while read -r from to _; do
    case "$from" in ''|'#'*) continue;; esac
    if [ ! -f "$src/$from" ]; then echo "sw-import: MISSING $src/$from (build it in cs150-1245)" >&2; miss=1; continue; fi
    if cmp -s "$src/$from" "$top/sw/$to"; then echo "  same     sw/$to"; else cp "$src/$from" "$top/sw/$to"; echo "  updated  sw/$to  <- $from"; fi
    n=$((n+1))
done < "$top/sw/MANIFEST"
echo "sw-import: $n image(s) from $cs150 ($rev)"
printf "cs150-1245 %s\n" "$rev" > "$top/sw/IMPORTED"
[ $miss -eq 0 ]
