#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: script/set-version.sh <version>" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/Sources/LintableKit/LintableVersion.swift"
sed -i.bak -E "s/static let current = \".*\"/static let current = \"$1\"/" "$FILE"
rm -f "$FILE.bak"
grep -q "\"$1\"" "$FILE"
echo "Version set to $1."
