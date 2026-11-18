#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: script/make-plugins-package.sh <bundle-url> <checksum> <output-dir>" >&2
  echo "  Writes the publishable LintablePlugins package, with the binary target pointing at <bundle-url>." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="$1"
CHECKSUM="$2"
OUTPUT="$3"

mkdir -p "$OUTPUT"
rm -rf "$OUTPUT/Plugins"
cp -R "$ROOT/LintablePlugins/Plugins" "$OUTPUT/Plugins"
cp "$ROOT/LintablePlugins/README.md" "$ROOT/LICENSE" "$OUTPUT/"
sed -E "s#\.binaryTarget\(name: \"LintableBinary\", path: \"LintableBinary\.artifactbundle\"\)#.binaryTarget(name: \"LintableBinary\", url: \"$URL\", checksum: \"$CHECKSUM\")#" \
  "$ROOT/LintablePlugins/Package.swift" > "$OUTPUT/Package.swift"
grep -q "checksum: \"$CHECKSUM\"" "$OUTPUT/Package.swift"
echo "$OUTPUT"
