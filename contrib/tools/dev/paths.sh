# Derived paths shared by project.sh and diffs.sh (sourced after machine.conf;
# requires ROOT). Repo-relative forms (*_REL) are used as patch header labels.

B3_REL="$SRC_DIR/$PRJ_DIR"
B3="$ROOT/$B3_REL"
XPR="$B3/$PRJ.xpr"

BOARD_TOP_REL="$SRC_DIR/$BOARD_TOP"
BOARD_TOP_PATH="$ROOT/$BOARD_TOP_REL"
WRAPPER_REL="$B3_REL/$PRJ.srcs/sources_1/new/$TOP.vhd"
WRAPPER="$ROOT/$WRAPPER_REL"
WRAPPER_PATCH="$ROOT/contrib/basys3/$(basename "$BOARD_TOP" .vhd)_to_basys3.patch"

XDC_ORIG_REL="contrib/third_party/digilent/Basys-3-Master.xdc"
XDC_ORIG="$ROOT/$XDC_ORIG_REL"
XDC_REL="$B3_REL/$PRJ.srcs/constrs_1/imports/digilent-xdc-master/Basys-3-Master.xdc"
XDC="$ROOT/$XDC_REL"
XDC_PATCH="$ROOT/contrib/basys3/${PRJ}_xdc.patch"

XPR_REL="$B3_REL/$PRJ.xpr"
XPR_PATCH="$ROOT/contrib/basys3/${PRJ}_xpr.patch"

CLK_DIR="$B3/$PRJ.srcs/sources_1/imports/clk_wiz_0"

# Third-party imports: every file in contrib/third_party/<party>/ except the
# Digilent XDC party is copied to sources_1/imports/<party>/ and patched there
# with contrib/basys3/<party>_<stem>.patch when that patch exists.
# third_party_imports prints one "<original> <import> <patch>" line per file.
third_party_imports() {
    local src party f
    for src in "$ROOT"/contrib/third_party/*/*; do
        [ -f "$src" ] || continue
        party="$(basename "$(dirname "$src")")"
        [ "$party" = digilent ] && continue
        f="$(basename "$src")"
        echo "$src $B3/$PRJ.srcs/sources_1/imports/$party/$f $ROOT/contrib/basys3/${party}_${f%.*}.patch"
    done
}
