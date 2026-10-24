#!/bin/bash
# Generate the PROM VHDL from the romset (SPEC.md section 4):
#   1. compile the upstream make_vhdl_prom (tools/tools_prom_src/src/) into
#      <SRC_DIR>/<PRJ_DIR>/proms/bin/;
#   2. unzip each romset into <SRC_DIR>/<UNZIP_DIR>/: ROMSET is a comma-separated
#      list of zip names (e.g. parent and clone), read from ROMDIR (default ~/roms);
#      ROMZIP, a comma-separated list of zip paths, overrides both;
#   3. run <PROM_SCRIPT> there; it writes the PROM VHDL into <SRC_DIR>/<PRJ_DIR>/proms/.
# Roms and generated PROM VHDL are gitignored and never distributed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"

src="$ROOT/$SRC_DIR"
romdir="${ROMDIR:-$HOME/roms}"
proms="$src/$PRJ_DIR/proms"
tool_dir="$proms/bin"

if [ -n "${ROMZIP:-}" ]; then
    IFS=, read -r -a romzips <<< "$ROMZIP"
else
    IFS=, read -r -a romzips <<< "$ROMSET"
    romzips=("${romzips[@]/#/$romdir/}")
fi
for z in "${romzips[@]}"; do
    if [ ! -f "$z" ]; then
        echo "error: romset not found: $z (set ROMDIR or ROMZIP)" >&2
        exit 1
    fi
done

mkdir -p "$tool_dir"
gcc -w "$src/tools/tools_prom_src/src/make_vhdl_prom.c" -lm -o "$tool_dir/make_vhdl_prom"

for z in "${romzips[@]}"; do
    unzip -q -o "$z" -d "$src/$UNZIP_DIR"
done

(cd "$src/$UNZIP_DIR" && MAKE_VHDL_PROM="$tool_dir/make_vhdl_prom" \
    PROM_DIR="$proms" bash "./$PROM_SCRIPT")

touch "$proms/.done"   # stamp for the Makefile bitstream prerequisite
echo "PROM VHDL:"
ls -1 "$proms"
