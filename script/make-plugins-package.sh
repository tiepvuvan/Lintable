#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: script/make-plugins-package.sh [--plugins-package <dir>] [--binary-target <name>] <bundle-url> <checksum> <output-dir>" >&2
  echo "  Writes a publishable copy of the plugins package in <dir> (default: LintablePlugins), with its" >&2
  echo "  binary target <name> (default: LintableBinary) pointing at <bundle-url>." >&2
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/LintablePlugins"
TARGET="LintableBinary"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugins-package) SOURCE="$(cd "${2:?--plugins-package needs a folder}" && pwd)"; shift ;;
    --binary-target) TARGET="${2:?--binary-target needs a name}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done

if [[ ${#POSITIONAL[@]} -ne 3 ]]; then
  usage
  exit 2
fi

URL="${POSITIONAL[0]}"
CHECKSUM="${POSITIONAL[1]}"
OUTPUT="${POSITIONAL[2]}"

mkdir -p "$OUTPUT"
rm -rf "${OUTPUT:?}/Plugins"
cp -R "$SOURCE/Plugins" "$OUTPUT/Plugins"
for file in README.md LICENSE; do
  if [[ -f "$SOURCE/$file" ]]; then
    cp "$SOURCE/$file" "$OUTPUT/$file"
  fi
done
sed -E "s#\.binaryTarget\(name: \"$TARGET\", path: \"$TARGET\.artifactbundle\"\)#.binaryTarget(name: \"$TARGET\", url: \"$URL\", checksum: \"$CHECKSUM\")#" \
  "$SOURCE/Package.swift" > "$OUTPUT/Package.swift"
grep -q "checksum: \"$CHECKSUM\"" "$OUTPUT/Package.swift"
echo "$OUTPUT"
