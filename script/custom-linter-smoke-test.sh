#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: script/custom-linter-smoke-test.sh [--with-binary]" >&2
  echo "  Builds and tests Templates/CustomLinter against this checkout, then runs its source plugin" >&2
  echo "  on Fixtures/CustomLinterSmokeTest/Source. --with-binary also builds the template's linter" >&2
  echo "  with the bundle scripts and runs its prebuilt plugin on Fixtures/CustomLinterSmokeTest/Binary." >&2
}

WITH_BINARY=0
for argument in "$@"; do
  case "$argument" in
    --with-binary) WITH_BINARY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/Templates/CustomLinter"
FIXTURES="$ROOT/Fixtures/CustomLinterSmokeTest"
EXPECTED_MESSAGE="\`print\` in \`render()\` of \`ChartView\`"

LINK_FOLDER="$(mktemp -d)"
trap 'rm -rf "${LINK_FOLDER:?}"' EXIT
ln -s "$ROOT" "$LINK_FOLDER/Lintable"
export LINTABLE_LOCAL_PATH="$LINK_FOLDER/Lintable"

expect_failure() {
  local description="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    echo "$output"
    echo "$description built; the plugin should have stopped it." >&2
    exit 1
  fi
  if ! grep -qF "$EXPECTED_MESSAGE" <<< "$output"; then
    echo "$output"
    echo "$description failed without the no_print_in_views error." >&2
    exit 1
  fi
}

swift test --package-path "$TEMPLATE"
RULES="$(swift run --package-path "$TEMPLATE" acme-lint rules)"
for rule in layout_lifecycle no_print_in_views; do
  if ! grep -q "^$rule " <<< "$RULES"; then
    echo "$RULES"
    echo "acme-lint rules doesn't list $rule." >&2
    exit 1
  fi
done
(cd "$TEMPLATE" && swift run acme-lint lint --reporter summary)
echo "Template: tests pass, acme-lint lists the built-in and the template's rules, and its sources are clean."

rm -rf "${FIXTURES:?}/Source/.build"
swift build --package-path "$FIXTURES/Source" --target Passing
echo "Source plugin: the passing target built."
expect_failure "The failing target" swift build --package-path "$FIXTURES/Source" --target Failing
echo "Source plugin: the failing target was stopped by no_print_in_views, as expected."

if [[ $WITH_BINARY -eq 1 ]]; then
  DIST="$TEMPLATE/.build/smoke-dist"
  rm -rf "${DIST:?}"
  "$ROOT/script/build-binary.sh" --host-only --product acme-lint --package-path "$TEMPLATE" "$DIST" > /dev/null
  "$ROOT/script/assemble-artifact-bundle.sh" --product acme-lint "0.0.0-smoke" "$DIST" "$DIST/bundle" > /dev/null
  rm -rf "${TEMPLATE:?}/AcmeLintPlugins/AcmeLintBinary.artifactbundle"
  cp -R "$DIST/bundle/acme-lint.artifactbundle" "$TEMPLATE/AcmeLintPlugins/AcmeLintBinary.artifactbundle"
  rm -rf "${FIXTURES:?}/Binary/.build"
  expect_failure "The binary plugin's failing target" swift build --package-path "$FIXTURES/Binary"
  echo "Binary plugin: the prebuilt acme-lint stopped the failing target, as expected."
fi
