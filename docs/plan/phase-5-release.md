# Phase 5: plugins and release 0.1.0

Ship the plugins, the release pipeline and the `LintablePlugins` package, then
release 0.1.0, so projects can add Lintable to their builds without compiling
swift-syntax.

Read first: [architecture.md](architecture.md), "Plugins" and "Distribution";
how SwiftLintPlugins is laid out (its `Package.swift` and plugin sources), which
this mirrors.

## Needs Peter's go-ahead

Each of these publishes something outside the repo; ask before doing it:
- creating the `tiepvuvan/LintablePlugins` repository;
- adding a repository secret for the release workflow to push to it;
- pushing the `0.1.0` tag, which publishes the GitHub release.

## Files

In `Lintable`:

```
script/build-artifact-bundle.sh
.github/workflows/release.yml
Fixtures/PluginSmokeTest/Package.swift
Fixtures/PluginSmokeTest/Sources/Smoke/ChartView.swift
Fixtures/PluginSmokeTest/.lintable.yml
```

In `LintablePlugins`:

```
Package.swift
Plugins/LintableBuildToolPlugin/Plugin.swift
Plugins/LintableCommandPlugin/Plugin.swift
README.md
LICENSE
```

## Steps

1. **Version.** The release workflow writes the tag's version into
   `LintableCommand`'s version file before building, so `lintable version` prints
   it.
2. **Artifact bundle** (`script/build-artifact-bundle.sh <version>`):
   - macOS: `swift build -c release --arch arm64 --arch x86_64`, one universal
     binary;
   - Linux x86_64 and aarch64: `swift build -c release --static-swift-stdlib` in
     the `swift:6.x` image, on matching runners;
   - assemble `lintable.artifactbundle/` with the `info.json` from
     architecture.md, zip it, and print `swift package compute-checksum`.
3. **Release workflow** (`release.yml`, on a `v*` tag): build the three
   binaries, assemble and zip the bundle, create the GitHub release with the zip,
   its checksum and the plain binaries, then update `LintablePlugins`'s
   `Package.swift` (URL and checksum), commit, and tag it with the same version.
4. **`LintablePlugins`.**
   - `binaryTarget` pointing at the release zip;
   - `LintableBuildToolPlugin` (`BuildToolPlugin` and, under
     `#if canImport(XcodeProjectPlugin)`, `XcodeBuildToolPlugin`): find the
     nearest `.lintable.yml` from the target's directory up to the package or
     project root (do nothing without one), write the target's Swift files to a
     list in the plugin work directory, return a prebuild command running
     `lintable lint --reporter xcode --files-from <list> --cache-path <work dir>`;
   - `LintableCommandPlugin` (`CommandPlugin` and `XcodeCommandPlugin`): run
     `lint` on chosen targets or the whole package, with the summary reporter;
   - a README with setup for Swift packages and Xcode projects, and the MIT
     license.
5. **Smoke tests**, in CI:
   - `Fixtures/PluginSmokeTest`: a package depending on `LintablePlugins` by
     local path (with a locally built bundle), whose `ChartView.swift` sets a
     frame in a gesture handler. `swift build` must fail with the rule's message
     at that line, and pass once the line is removed;
   - the same against an Xcode project with `xcodebuild`, on macOS.
6. **Docs.** The README's status becomes "0.1.0", with install steps for the
   plugin, Mint and the plain binary, and the list of rules. `CHANGELOG.md` gets
   the 0.1.0 section.
7. **Release.** With Peter's go-ahead, tag `v0.1.0`.

## Verify

```bash
script/build-artifact-bundle.sh 0.1.0-test
```

- The smoke tests fail and pass as described, on macOS and Linux.
- After the release: a fresh package that adds `LintablePlugins` from GitHub
  builds with the plugin, downloads only the zip (no swift-syntax checkout in
  `.build/checkouts`), and reports the smoke violation.

## Done

0.1.0 is released, `LintablePlugins` points at it, and both plugins work in a
Swift package and an Xcode project. Habitify can turn the rule on. One commit in
each repo, plus the tag.
