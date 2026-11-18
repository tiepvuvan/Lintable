#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: script/assemble-artifact-bundle.sh <version> <dist-dir> [output-dir]" >&2
  echo "  Packs <dist-dir>/{macos,linux-x86_64,linux-aarch64}/lintable into lintable.artifactbundle(.zip)." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$1"
DIST="$(cd "$2" && pwd)"
OUTPUT="${3:-$DIST}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
BUNDLE="$OUTPUT/lintable.artifactbundle"

rm -rf "$BUNDLE" "$OUTPUT/lintable.artifactbundle.zip"
mkdir -p "$BUNDLE"
cp "$ROOT/LICENSE" "$BUNDLE/LICENSE"

VARIANTS=()
add_variant() {
  local source="$1" folder="$2" triples="$3"
  [[ -f "$source" ]] || return 0
  mkdir -p "$BUNDLE/$folder/bin"
  cp "$source" "$BUNDLE/$folder/bin/lintable"
  chmod +x "$BUNDLE/$folder/bin/lintable"
  VARIANTS+=("        { \"path\": \"$folder/bin/lintable\", \"supportedTriples\": [$triples] }")
}

add_variant "$DIST/macos/lintable" "lintable-macos" '"arm64-apple-macosx", "x86_64-apple-macosx"'
add_variant "$DIST/linux-x86_64/lintable" "lintable-linux-x86_64" '"x86_64-unknown-linux-gnu"'
add_variant "$DIST/linux-aarch64/lintable" "lintable-linux-aarch64" '"aarch64-unknown-linux-gnu"'

if [[ ${#VARIANTS[@]} -eq 0 ]]; then
  echo "No binaries found under $DIST." >&2
  exit 1
fi

{
  echo '{'
  echo '  "schemaVersion": "1.0",'
  echo '  "artifacts": {'
  echo '    "lintable-cli": {'
  echo '      "type": "executable",'
  echo "      \"version\": \"$VERSION\","
  echo '      "variants": ['
  for index in "${!VARIANTS[@]}"; do
    if [[ $index -lt $((${#VARIANTS[@]} - 1)) ]]; then
      echo "${VARIANTS[$index]},"
    else
      echo "${VARIANTS[$index]}"
    fi
  done
  echo '      ]'
  echo '    }'
  echo '  }'
  echo '}'
} > "$BUNDLE/info.json"

(cd "$OUTPUT" && zip -qry lintable.artifactbundle.zip lintable.artifactbundle)
CHECKSUM="$(cd "$ROOT" && swift package compute-checksum "$OUTPUT/lintable.artifactbundle.zip")"
echo "$CHECKSUM" > "$OUTPUT/lintable.artifactbundle.zip.sha256"
echo "$BUNDLE"
echo "$OUTPUT/lintable.artifactbundle.zip"
echo "checksum $CHECKSUM"
