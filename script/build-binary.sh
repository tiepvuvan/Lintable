#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: script/build-binary.sh [--host-only] [--product <name>] [--package-path <dir>] [output-dir]" >&2
  echo "  Builds a release <name> (default: lintable) from the package in <dir> (default: this repository)" >&2
  echo "  into <output-dir>/<platform>/<name>. <output-dir> defaults to <dir>/dist." >&2
  echo "  On macOS it builds a universal binary unless --host-only is given." >&2
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_ONLY=0
OUTPUT=""
PRODUCT="lintable"
PACKAGE="$ROOT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-only) HOST_ONLY=1 ;;
    --product) PRODUCT="${2:?--product needs a name}"; shift ;;
    --package-path) PACKAGE="$(cd "${2:?--package-path needs a folder}" && pwd)"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) OUTPUT="$1" ;;
  esac
  shift
done

OUTPUT="${OUTPUT:-$PACKAGE/dist}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
cd "$PACKAGE"

case "$(uname -s)" in
  Darwin)
    if [[ $HOST_ONLY -eq 1 ]]; then
      swift build -c release --product "$PRODUCT"
      BINARY="$(swift build -c release --show-bin-path)/$PRODUCT"
    else
      swift build -c release --product "$PRODUCT" --arch arm64 --arch x86_64
      BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$PRODUCT"
    fi
    PLATFORM="macos"
    ;;
  Linux)
    swift build -c release --product "$PRODUCT" --static-swift-stdlib
    BINARY="$(swift build -c release --static-swift-stdlib --show-bin-path)/$PRODUCT"
    PLATFORM="linux-$(uname -m)"
    ;;
  *)
    echo "Unsupported platform $(uname -s)." >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT/$PLATFORM"
cp "$BINARY" "$OUTPUT/$PLATFORM/$PRODUCT"
strip -S "$OUTPUT/$PLATFORM/$PRODUCT" 2>/dev/null || true
echo "$OUTPUT/$PLATFORM/$PRODUCT"
