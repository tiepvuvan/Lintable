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
GATE="$ROOT/Fixtures/PluginSmokeTest/ReleaseGate"
rm -rf "$FAILING/.build" "$PASSING/.build" "$GATE/.build"

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

if ! OUTPUT="$(swift build --package-path "$GATE" 2>&1)"; then
  echo "$OUTPUT"
  echo "The release gate fixture failed a debug build; a missing translation should only warn there." >&2
  exit 1
fi
echo "Release gate fixture: debug build passed with the missing translation."

if OUTPUT="$(swift build --package-path "$GATE" -c release 2>&1)"; then
  echo "$OUTPUT"
  echo "The release gate fixture built in release; the gate should have stopped it." >&2
  exit 1
fi
if ! grep -q "missing_translation warning stops release builds" <<< "$OUTPUT"; then
  echo "$OUTPUT"
  echo "The release build failed without the release gate's error." >&2
  exit 1
fi
echo "Release gate fixture: release build stopped by the gate, as expected."
