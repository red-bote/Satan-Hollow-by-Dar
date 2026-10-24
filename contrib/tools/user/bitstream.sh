#!/bin/bash
# Build the bitstream from the tracked .xpr (SPEC.md section 4). Vivado runs
# from /tmp. Path is localized before the open (see localize_xpr.sh); the tracked
# .xpr is restored afterwards: Vivado rewrites it on open/run (Path, run state),
# which is not a functional change.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"

VIVADO="${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}"
xpr="$ROOT/$SRC_DIR/$PRJ_DIR/$PRJ.xpr"
work="/tmp/${PRJ}_bitstream"

if ! ls "$ROOT/$SRC_DIR/$PRJ_DIR/proms/"*.vhd > /dev/null 2>&1; then
    echo "error: PROM VHDL missing; run 'make roms' first" >&2
    exit 1
fi

mkdir -p "$work"
cp "$xpr" "$work/saved.xpr"
"$ROOT/contrib/tools/user/localize_xpr.sh" "$xpr"
status=0
(cd "$work" && "$VIVADO" -mode batch -nolog -nojournal \
    -source "$ROOT/contrib/tools/user/build.tcl" -tclargs "$xpr") || status=$?
cp "$work/saved.xpr" "$xpr"
rm -rf "$work"

[ "$status" -eq 0 ] || exit "$status"
echo "Bitstream: $ROOT/$SRC_DIR/$PRJ_DIR/$PRJ.runs/impl_1/$TOP.bit"
