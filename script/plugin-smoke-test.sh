#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/.build/smoke-dist"
cd "$ROOT"

rm -rf "$DIST"
"$ROOT/script/build-binary.sh" --host-only "$DIST" > /dev/null
"$ROOT/script/assemble-artifact-bundle.sh" "0.0.0-smoke" "$DIST" "$DIST/bundle" > /dev/null
rm -rf "$ROOT/LintablePlugins/LintableBinary.artifactbundle"
cp -R "$DIST/bundle/lintable.artifactbundle" "$ROOT/LintablePlugins/LintableBinary.artifactbundle"

FAILING="$ROOT/Fixtures/PluginSmokeTest/Failing"
PASSING="$ROOT/Fixtures/PluginSmokeTest/Passing"
rm -rf "$FAILING/.build" "$PASSING/.build"

if OUTPUT="$(swift build --package-path "$FAILING" 2>&1)"; then
  echo "$OUTPUT"
  echo "The failing fixture built; the plugin should have stopped it." >&2
  exit 1
fi
if ! grep -q "is set in \`handlePan()\`, outside the layout pass" <<< "$OUTPUT"; then
  echo "$OUTPUT"
  echo "The failing fixture failed without the layout_lifecycle error." >&2
  exit 1
fi
echo "Failing fixture: stopped by layout_lifecycle, as expected."

swift build --package-path "$PASSING"
echo "Passing fixture: built."
