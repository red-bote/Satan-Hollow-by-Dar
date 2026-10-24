#!/bin/bash
# Regenerate contrib/basys3/*.patch from the tracked project files against their
# originals (SPEC.md section 3, step 8). The .xpr baseline is a freshly created
# and normalized empty project (Vivado runs from /tmp).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"
. "$ROOT/contrib/tools/dev/paths.sh"

VIVADO="${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}"
T="$ROOT/contrib/tools/dev"
work="/tmp/${PRJ}_diffs"

# mkpatch <orig> <orig_label> <new> <new_label> <out>: an existing leading '#' header
# in <out> is kept.
mkpatch() {
    local rc=0 hdr=""
    [ -f "$5" ] && hdr="$(sed -n '/^#/!q;p' "$5")"
    { [ -n "$hdr" ] && printf '%s\n' "$hdr"
      diff -u --label "a/$2" --label "b/$4" "$1" "$3" || rc=$?
    } > "$5.tmp"
    [ "$rc" -le 1 ] || { rm -f "$5.tmp"; echo "error: diff failed for $3" >&2; exit 1; }
    mv "$5.tmp" "$5"
    echo "wrote $5 ($(grep -c '^[-+][^-+]' "$5" || true) changed lines)"
}

# The wrapper patch base is a normalized copy of the board top (the tracked board top
# stays as shipped).
rm -rf "$work"
mkdir -p "$work"
board_top="$work/$(basename "$BOARD_TOP")"
cp "$BOARD_TOP_PATH" "$board_top"
"$T/normalize_file.sh" "$board_top"
mkpatch "$board_top" "$BOARD_TOP_REL" "$WRAPPER" "$WRAPPER_REL" "$WRAPPER_PATCH"
mkpatch "$XDC_ORIG" "$XDC_ORIG_REL" "$XDC" "$XDC_REL" "$XDC_PATCH"

# Third-party imports: a patch only when the import differs from the original.
third_party_imports | while read -r orig imp p; do
    if cmp -s "$orig" "$imp"; then
        rm -f "$p"
    else
        mkpatch "$orig" "${orig#$ROOT/}" "$imp" "${imp#$ROOT/}" "$p"
    fi
done

rm -rf "$work"
mkdir -p "$work"
(cd "$work" && "$VIVADO" -mode batch -nolog -nojournal \
    -source "$T/empty_project.tcl" -tclargs "$work/empty" "$PRJ" "$PART")
"$ROOT/contrib/tools/user/normalize_xpr.sh" "$work/empty/$PRJ.xpr"
mkpatch "$work/empty/$PRJ.xpr" "$XPR_REL" "$XPR" "$XPR_REL" "$XPR_PATCH"
rm -rf "$work"
