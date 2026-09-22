#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version=$(awk -F= '$1 == "version" { print $2 }' module/module.prop)
mkdir -p dist
archive="dist/aod-battery-saver-override-$version.zip"
rm -f "$archive"
zip -q -j -X "$archive" module/* LICENSE README.md CHANGELOG.md
printf '%s\n' "$archive"
