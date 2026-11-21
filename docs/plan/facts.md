# Facts

Updated on 2026-11-21, after phases 0–6 were built. "Verified" means checked on the
machine or in the code; "assumed" means a later phase or CI has to confirm it.

## Verified

### Toolchain and dependencies

- The development Mac has Swift 6.4 (`swiftlang-6.4.0.34.1`), Xcode 27.1 (27A9269),
  SwiftLint and the GitHub CLI (`gh`) installed through Homebrew.
- swift-syntax 604.0.0 is the release for Swift 6.4. Lintable pins `from: "604.0.0"`,
  swift-argument-parser `from: "1.8.0"` and Yams `from: "6.2.0"`.
- SwiftPM uses a prebuilt swift-syntax for debug builds on this machine, so a debug
  build of the whole package takes seconds. A release build of `lintable` compiles
  swift-syntax and took about 2 minutes 15 seconds.
- A regular library target can `import Testing` and call `Issue.record` with
  `#_sourceLocation`, so `LintableTesting` reports failures at the caller's line.
- swift-syntax parses `#selector(…)` as a `MacroExpansionExprSyntax`.
- `OperatorTable.standardOperators.foldAll` keeps token positions, so assignments are
  `InfixOperatorExprSyntax` after folding; unfoldable sequences fall back to
  `SequenceExprSyntax`.

### Plugins

- `PackagePlugin`'s `Target.directoryURL` needs swift-tools-version 6.1, so
  `LintablePlugins/Package.swift` declares 6.1.
- A build-tool plugin whose tool is a binary target runs as a prebuild command, and a
  non-zero exit fails the build with the tool's `path:line:col: error:` lines shown as
  errors. Writing the file list into the plugin work directory is allowed.
- `script/plugin-smoke-test.sh` passes on macOS: the failing fixture is stopped by
  `layout_lifecycle`, and the passing one builds. `swift package lintable` runs the
  command plugin and prints the summary.

### Custom rule packages

Checked on 2026-11-21 while building phase 6:

- A build-tool plugin whose tool is built from source returns a build command. With
  the target's files and the config as inputs and the release gate file as its only
  output, `swift build` skips it when nothing changed, runs it again after an edit,
  and runs it again after it failed.
- A local binary target whose artifact bundle is missing stops every build of the
  package, even of a target that doesn't use it ("does not contain a binary
  artifact"), so a prebuilt plugin lives in its own package.
- SwiftPM names a path dependency after its folder: a dependency at
  `…/lintable-phase6` is `lintable-phase6`, and `.product(…, package: "Lintable")`
  fails. A symlink named `Lintable` to the checkout works, which is what
  `script/custom-linter-smoke-test.sh` uses.
- On this Mac a clean debug build of a package that uses the template's source plugin
  took about 22 seconds, with SwiftPM's prebuilt swift-syntax. A release build of
  `acme-lint` for the prebuilt plugin took about 2 minutes.

### CI

From the first CI run, on 2026-11-18:

- GitHub's `macos-15` runner has Swift 6.1.2 (Xcode 16.4), not 6.4. Lintable
  builds and its tests pass there; SwiftPM compiles swift-syntax from source, so
  the job takes about 7 minutes.
- The `swift:6.4` image builds and tests Lintable on Linux, in about 2 minutes.
- Swift 6.1's `swift build` stopped the plugin smoke test: "a prebuild command
  cannot use executables built from source, including executable target
  'lintable'". Its check compares the executable's file name with the names of
  all the tools the plugin can use, binary targets included
  ([swift-package-manager#8440](https://github.com/swiftlang/swift-package-manager/pull/8440)
  fixed it later, and SwiftLint's plugin hit the same error). Xcode builds and
  Swift 6.2 and later check paths instead. The bundle names its artifact
  `lintable-cli`, which that name check can't confuse with the `lintable`
  executable.

### Habitify, the first adopter

Run on 2026-11-18 over 1,008 Swift files with `layout_lifecycle` at its defaults
(details are in Habitify's private adoption plan; only counts here):

- 31 violations in 19 files.
- Every site the hand-checked inventory expected is reported: 29 writes in 23
  functions plus 3 layer `position` writes. Two of them are reported more
  precisely, at the 2 calls of a private `layout…` helper from animation blocks
  outside layout.
- Nothing is reported on the 11 collection view layout attribute writes, the 17
  writes in UIKit transition code (12 in transition callbacks, 5 in private
  functions that only those callbacks call), or the local variable named `frame`.
  The first run reported those 5, when only `layout…` helpers were exempt; Peter
  chose to treat a transition's private functions as part of the transition.
- Timing on an Apple silicon Mac, release build: 1.4 s cold, 0.7 s with the cache.

## Assumed

| Fact | Phase |
|---|---|
| `--static-swift-stdlib` produces Linux binaries that run on Ubuntu 22.04 and 24.04 without a Swift install | Release |
| GitHub's `ubuntu-24.04-arm` runner builds the aarch64 binary | Release |
| The universal macOS binary plus two Linux binaries make a zip of a few tens of megabytes | Release |
| The release workflow can push to `tiepvuvan/LintablePlugins` with a `PLUGINS_REPO_TOKEN` secret | Release |
