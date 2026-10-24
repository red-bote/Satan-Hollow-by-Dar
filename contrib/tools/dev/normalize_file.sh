#!/bin/bash
# Normalize one text file in place (SPEC.md section 3, step 4): CRLF/CR -> LF, trailing
# whitespace stripped, final newline; .vhd re-indented by vhdl_formatter.py (2-space, no
# align). Check: content with all whitespace removed is unchanged, else the file is
# restored and the script fails. Binary files are left alone. Idempotent.
#
# Usage: normalize_file.sh <file>

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
f="${1:?usage: normalize_file.sh <file>}"

grep -Iq . "$f" || exit 0   # binary

squash() { tr -d ' \t\r\n\f\v' < "$1"; }

before="$(mktemp)"
cp "$f" "$before"

sed -i -e 's/\r$//' -e 's/\r/\n/g' -e 's/[ \t]*$//' "$f"
[ -n "$(tail -c1 "$f")" ] && echo >> "$f"
case "$f" in
    *.vhd|*.VHD) python3 -I "$HERE/vhdl_formatter.py" "$f" > /dev/null 2>&1 ;;
esac

status=0
if ! cmp -s <(squash "$before") <(squash "$f"); then
    echo "error: non-whitespace change in $f; restored" >&2
    cp "$before" "$f"
    status=1
fi
rm -f "$before"
exit "$status"
