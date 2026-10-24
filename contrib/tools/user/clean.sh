#!/bin/bash
# Remove build outputs (SPEC.md section 4): Vivado run/cache directories,
# generated PROM VHDL with the compiled make_vhdl_prom (proms/bin/) and the
# unzipped roms. Tracked files are untouched.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"

prj="$ROOT/$SRC_DIR/$PRJ_DIR"
rm -rf "$prj/$PRJ".{cache,gen,hw,ip_user_files,runs,sim} "$prj/proms" "$ROOT/.Xil"

# Unzipped roms: everything in the staging dir except the upstream scripts/tool and the
# .sh port (mirrors .gitignore).
find "$ROOT/$SRC_DIR/$UNZIP_DIR" -maxdepth 1 -type f \
    ! -name '*.bat' ! -name '*.exe' ! -name '*.sh' -delete
