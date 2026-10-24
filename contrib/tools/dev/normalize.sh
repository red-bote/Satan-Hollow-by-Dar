#!/bin/bash
# Normalize an extracted source tree (SPEC.md section 3, step 4). Only the files the
# patches modify are normalized: the targets of contrib/patches/*.patch
# (normalize_file.sh: LF, trailing whitespace, final newline, .vhd re-indent). Every
# other upstream file, including the board top <BOARD_TOP> (project.sh and diffs.sh
# normalize a temporary copy of it), is left as shipped, so the published tree differs
# from the zip only where the port changes it. File names containing spaces are
# renamed in the whole tree, spaces to '_' (a collision is an error). Idempotent.
#
# Usage: normalize.sh <dir>   (<dir> = <SRC_DIR>, as extracted under the repo root)

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
dir="${1:?usage: normalize.sh <dir>}"
. "$ROOT/machine.conf"

fail=0
while IFS= read -r -d '' f; do
    new="$(dirname "$f")/$(basename "$f" | tr ' ' '_')"
    if [ -e "$new" ]; then
        echo "error: cannot rename '$f': $new exists" >&2
        fail=1
        continue
    fi
    mv "$f" "$new"
    echo "renamed: $f -> $new"
done < <(find "$dir" -type f -name '* *' -print0)

# Files the patches modify, as paths below <SRC_DIR>/ (creation patches have no
# 'a/' side and are skipped).
while IFS= read -r rel; do
    f="$dir/$rel"
    [ -f "$f" ] || continue
    "$HERE/normalize_file.sh" "$f" || fail=1
done < <(sed -n "s|^--- a/$SRC_DIR/||p" "$ROOT"/contrib/patches/*.patch 2>/dev/null | sort -u)

exit "$fail"
