#!/bin/bash
# Generate the Vivado project from its originals and contrib/basys3/*.patch
# (SPEC.md section 3, step 7). Vivado runs from /tmp. A missing patch is
# skipped with a notice (first-time authoring; see diffs.sh).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"
. "$ROOT/contrib/tools/dev/paths.sh"

VIVADO="${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}"
T="$ROOT/contrib/tools/dev"
work="/tmp/${PRJ}_project"

step() { printf '\n==> %s\n' "$1"; }

# apply_to <original> <target> <patch>: copy original to target, apply patch.
apply_to() {
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    if [ -f "$3" ]; then
        patch -s --no-backup-if-mismatch "$2" < "$3"
    else
        echo "notice: $3 missing; $2 left as the unpatched original"
    fi
}

rm -rf "$work" "$B3/$PRJ.xpr" "$B3/$PRJ".{srcs,cache,gen,hw,ip_user_files,runs,sim}
mkdir -p "$work" "$B3"

step "1/6 Empty project"
(cd "$work" && "$VIVADO" -mode batch -nolog -nojournal \
    -source "$T/empty_project.tcl" -tclargs "$B3" "$PRJ" "$PART")
"$ROOT/contrib/tools/user/normalize_xpr.sh" "$XPR"

step "2/6 Wrapper ($BOARD_TOP, normalized copy + patch)"
board_top="$work/$(basename "$BOARD_TOP")"
cp "$BOARD_TOP_PATH" "$board_top"
"$T/normalize_file.sh" "$board_top"
apply_to "$board_top" "$WRAPPER" "$WRAPPER_PATCH"

step "3/6 XDC (Digilent template + patch)"
apply_to "$XDC_ORIG" "$XDC" "$XDC_PATCH"

step "4/6 Third-party imports"
third_party_imports | while read -r orig imp p; do
    mkdir -p "$(dirname "$imp")"
    cp "$orig" "$imp"
    [ -f "$p" ] && patch -s --no-backup-if-mismatch "$imp" < "$p"
    echo "${imp#$ROOT/}"
done

step "5/6 clk_wiz_0 ($CLK_MHZ MHz)"
(cd "$work" && "$VIVADO" -mode batch -nolog -nojournal \
    -source "$T/clk_wiz.tcl" -tclargs "$work/clk_wiz" "$PART" "$CLK_MHZ")
mkdir -p "$CLK_DIR"
cp "$work/clk_wiz/clk_wiz_0/clk_wiz_0.v" "$work/clk_wiz/clk_wiz_0/clk_wiz_0_clk_wiz.v" "$CLK_DIR/"

step "6/6 .xpr patch"
if [ -f "$XPR_PATCH" ]; then
    patch -s --no-backup-if-mismatch "$XPR" < "$XPR_PATCH"
else
    echo "notice: $XPR_PATCH missing; $XPR left empty"
fi

rm -rf "$work"
echo
echo "Project: $XPR"
