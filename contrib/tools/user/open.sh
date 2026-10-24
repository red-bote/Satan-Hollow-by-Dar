#!/bin/bash
# Open the tracked project in the Vivado GUI (SPEC.md section 4). Vivado runs
# from /tmp. Path is localized before the open and Path/Id are normalized after
# exit; project edits made in the GUI are kept (dev: follow with make diffs).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"

VIVADO="${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}"
xpr="$ROOT/$SRC_DIR/$PRJ_DIR/$PRJ.xpr"
work="/tmp/${PRJ}_open"

mkdir -p "$work"
"$ROOT/contrib/tools/user/localize_xpr.sh" "$xpr"
status=0
(cd "$work" && "$VIVADO" -mode gui -nolog -nojournal "$xpr") || status=$?
"$ROOT/contrib/tools/user/normalize_xpr.sh" "$xpr"
rm -rf "$work"
exit "$status"
