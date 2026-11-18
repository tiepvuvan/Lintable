# Facts

Checked on 2026-11-18. "Verified" means checked on the machine or in the code;
"assumed" means a phase has to confirm it and update this file.

## Verified

- The repo is empty: branch `main`, no commits, remote
  `https://github.com/tiepvuvan/Lintable.git`.
- The development Mac has Swift 6.4 (`swiftlang-6.4.0.34.1`), Xcode 27.1
  (27A9269), SwiftLint and the GitHub CLI (`gh`) installed through Homebrew.
- Habitify, the first adopter, already runs SwiftLint 0.65.1 through
  `SwiftLintPlugins` on all 11 of its Xcode targets and in all 21 of its local
  packages. Lintable's plugin goes next to it, the same way.
- Habitify's SwiftLint `no_comments` rule allows only `// swiftlint:` comments, so
  Habitify has to allow `// lintable:` before using directives.
- A heuristic scan of Habitify found 61 view-geometry writes outside layout
  methods: 11 on collection view layout attributes and 17 in UIKit transition code
  (both must stay silent under `layout_lifecycle`), 1 on a local variable named
  `frame` (must stay silent), and 29 writes in 23 functions plus 3 layer
  `position` writes that should be reported. Habitify's
  private adoption plan has the per-site list. Phase 4 checks the rule against it.

## Assumed

| Fact | Phase |
|---|---|
| swift-syntax's release line for Swift 6.4 is 604.x; Lintable pins it with `from:` and builds with the toolchains CI uses | 0 |
| swift-argument-parser 1.x and Yams 5.x or later build on macOS and Linux with Swift 6 | 0 |
| GitHub Actions has a macOS runner with an Xcode that ships Swift 6.x, and the `swift:6.x` Docker images work for Linux | 0 |
| swift-syntax's `SyntaxProtocol` nodes are `Sendable`, so a `LintFile` can cross tasks without copying | 1 |
| A file of a few thousand lines parses in tens of milliseconds, so the index can be built per file without a shared cache | 1 |
| A SwiftPM prebuild command can only run a binary tool; a source-built tool needs a build command with inputs and outputs | 5, 6 |
| Writing the file list into the plugin work directory is allowed by the plugin sandbox | 5 |
| `--static-swift-stdlib` produces Linux binaries that run on Ubuntu 22.04 and 24.04 without a Swift install | 5 |
| A release with swift-syntax linked in is a few tens of megabytes per platform | 5 |
| Cold run under 5 s and cached run under 1 s on Habitify's ~1,000 files | 4 |
