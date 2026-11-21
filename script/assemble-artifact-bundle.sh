#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: script/assemble-artifact-bundle.sh [--product <name>] [--license <file>] <version> <dist-dir> [output-dir]" >&2
  echo "  Packs <dist-dir>/{macos,linux-x86_64,linux-aarch64}/<name> into <name>.artifactbundle(.zip)," >&2
  echo "  with one executable artifact named <name>-cli. <name> defaults to lintable, and the" >&2
  echo "  bundle's LICENSE to Lintable's." >&2
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="lintable"
LICENSE_FILE="$ROOT/LICENSE"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --product) PRODUCT="${2:?--product needs a name}"; shift ;;
    --license) LICENSE_FILE="${2:?--license needs a file}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done

if [[ ${#POSITIONAL[@]} -lt 2 || ${#POSITIONAL[@]} -gt 3 ]]; then
  usage
  exit 2
fi

VERSION="${POSITIONAL[0]}"
DIST="$(cd "${POSITIONAL[1]}" && pwd)"
OUTPUT="${POSITIONAL[2]:-$DIST}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
BUNDLE="$OUTPUT/$PRODUCT.artifactbundle"
ARCHIVE="$PRODUCT.artifactbundle.zip"

rm -rf "$BUNDLE" "${OUTPUT:?}/$ARCHIVE"
mkdir -p "$BUNDLE"
cp "$LICENSE_FILE" "$BUNDLE/LICENSE"

VARIANTS=()
add_variant() {
  local source="$1" folder="$2" triples="$3"
  [[ -f "$source" ]] || return 0
  mkdir -p "$BUNDLE/$folder/bin"
  cp "$source" "$BUNDLE/$folder/bin/$PRODUCT"
  chmod +x "$BUNDLE/$folder/bin/$PRODUCT"
  VARIANTS+=("        { \"path\": \"$folder/bin/$PRODUCT\", \"supportedTriples\": [$triples] }")
}

add_variant "$DIST/macos/$PRODUCT" "$PRODUCT-macos" '"arm64-apple-macosx", "x86_64-apple-macosx"'
add_variant "$DIST/linux-x86_64/$PRODUCT" "$PRODUCT-linux-x86_64" '"x86_64-unknown-linux-gnu"'
add_variant "$DIST/linux-aarch64/$PRODUCT" "$PRODUCT-linux-aarch64" '"aarch64-unknown-linux-gnu"'

if [[ ${#VARIANTS[@]} -eq 0 ]]; then
  echo "No $PRODUCT binaries found under $DIST." >&2
  exit 1
fi

{
  echo '{'
  echo '  "schemaVersion": "1.0",'
  echo '  "artifacts": {'
  echo "    \"$PRODUCT-cli\": {"
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

(cd "$OUTPUT" && zip -qry "$ARCHIVE" "$PRODUCT.artifactbundle")
CHECKSUM="$(cd "$ROOT" && swift package compute-checksum "$OUTPUT/$ARCHIVE")"
echo "$CHECKSUM" > "$OUTPUT/$ARCHIVE.sha256"
echo "$BUNDLE"
echo "$OUTPUT/$ARCHIVE"
echo "checksum $CHECKSUM"
