#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: script/build-binary.sh [--host-only] [output-dir]" >&2
  echo "  Builds a release lintable for this platform into <output-dir>/<platform>/lintable." >&2
  echo "  On macOS it builds a universal binary unless --host-only is given." >&2
}

HOST_ONLY=0
OUTPUT=""
for argument in "$@"; do
  case "$argument" in
    --host-only) HOST_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) OUTPUT="$argument" ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${OUTPUT:-$ROOT/dist}"
cd "$ROOT"

case "$(uname -s)" in
  Darwin)
    if [[ $HOST_ONLY -eq 1 ]]; then
      swift build -c release --product lintable
      BINARY="$(swift build -c release --show-bin-path)/lintable"
    else
      swift build -c release --product lintable --arch arm64 --arch x86_64
      BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/lintable"
    fi
    PLATFORM="macos"
    ;;
  Linux)
    swift build -c release --product lintable --static-swift-stdlib
    BINARY="$(swift build -c release --static-swift-stdlib --show-bin-path)/lintable"
    PLATFORM="linux-$(uname -m)"
    ;;
  *)
    echo "Unsupported platform $(uname -s)." >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT/$PLATFORM"
cp "$BINARY" "$OUTPUT/$PLATFORM/lintable"
strip -S "$OUTPUT/$PLATFORM/lintable" 2>/dev/null || true
echo "$OUTPUT/$PLATFORM/lintable"
