#!/bin/bash
# Inverse of normalize_xpr.sh for the Path attribute: set <Project Path> to the
# .xpr's real absolute location before Vivado opens it. With the placeholder
# Path, Vivado treats the project as moved from its working directory (/tmp)
# and re-expresses non-existent paths (run AutoIncrementalDir) against /tmp.
#
# Usage: localize_xpr.sh <xpr>

set -euo pipefail

xpr="$(realpath "${1:?usage: localize_xpr.sh <xpr>}")"

sed -i -e "s|^\(<Project [^>]*Path=\"\)[^\"]*\"|\1$xpr\"|" "$xpr"
