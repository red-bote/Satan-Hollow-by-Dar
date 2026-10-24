#!/bin/bash
# Apply contrib/patches/*.patch in place to the upstream tree (SPEC.md section 3,
# step 6). Paths in the patches are a/<SRC_DIR>/..., applied with -p1 from the
# repo root. A patch that already reverse-applies is skipped; one that applies
# neither way fails.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

for p in contrib/patches/*.patch; do
    [ -e "$p" ] || continue
    if patch -p1 -R --dry-run --forward -s < "$p" > /dev/null 2>&1; then
        echo "already applied: $p"
    elif patch -p1 --dry-run --forward -s < "$p" > /dev/null 2>&1; then
        echo "applying: $p"
        patch -p1 --forward --no-backup-if-mismatch -s < "$p"
    else
        echo "error: $p does not apply (context mismatch)" >&2
        exit 1
    fi
done
