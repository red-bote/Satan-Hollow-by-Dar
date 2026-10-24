#!/bin/bash
# Replace the run-specific fields Vivado writes into a new .xpr (SPEC.md
# section 3, step 7.1): the absolute Path attribute of <Project> and the random
# project GUID (<Option Name="Id">). Fixed placeholders make the empty project a
# stable baseline for the .xpr patch.
#
# Usage: normalize_xpr.sh <xpr>

set -euo pipefail

xpr="${1:?usage: normalize_xpr.sh <xpr>}"
name="$(basename "$xpr")"

sed -i \
    -e "s|^\(<Project [^>]*Path=\"\)[^\"]*\"|\1$name\"|" \
    -e 's|\(<Option Name="Id" Val="\)[0-9a-f]*"|\100000000000000000000000000000000"|' \
    "$xpr"
