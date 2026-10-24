#!/bin/bash
# Fetch the upstream source archive into dloads/ (SPEC.md section 3, step 2).
# Reuses a cached copy only if its SHA-256 matches ZIP_SHA256; otherwise
# downloads ZIP_URL and hard-fails on a hash mismatch.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/machine.conf"

zip="$ROOT/dloads/$SRC_DIR.zip"
mkdir -p "$ROOT/dloads"

if [ -f "$zip" ]; then
    if [ "$(sha256sum "$zip" | cut -d' ' -f1)" = "$ZIP_SHA256" ]; then
        echo "Using cached $zip (SHA-256 verified)"
        exit 0
    fi
    echo "warning: cached archive hash mismatch; re-downloading" >&2
    rm -f "$zip"
fi

wget -O "$zip" "$ZIP_URL"
if [ "$(sha256sum "$zip" | cut -d' ' -f1)" != "$ZIP_SHA256" ]; then
    echo "error: downloaded archive failed SHA-256 check" >&2
    rm -f "$zip"
    exit 1
fi
echo "Downloaded $zip (SHA-256 verified)"
