# Phase 0: foundation

Set up the package, the open-source files and CI, so every later phase lands on a
repo that builds, tests and lints itself on macOS and Linux.

Read first: [README.md](README.md), [architecture.md](architecture.md) (targets),
[facts.md](facts.md).

## Files

```
Package.swift
Sources/LintableKit/
Sources/LintableEngine/
Sources/LintableCommand/
Sources/LintableRules/
Sources/LintableTesting/
Sources/lintable/main.swift
Tests/LintableKitTests/
Tests/LintableEngineTests/
Tests/LintableRulesTests/
LICENSE
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
CHANGELOG.md
.swiftlint.yml
.gitignore
.github/workflows/ci.yml
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/rule_proposal.yml
.github/pull_request_template.md
```

## Steps

1. **`Package.swift`.** `swift-tools-version: 6.0`, `platforms: [.macOS(.v13)]`,
   Swift 6 language mode. The targets and products from architecture.md.
   Dependencies, each pinned with `from:` to the current release (confirm the
   versions in facts.md): swift-syntax (`SwiftSyntax`, `SwiftParser`),
   swift-argument-parser, Yams. No plugin products, and no SwiftLint plugin
   dependency: adopters would download it too.
2. **A building skeleton.** One small file per target. `lintable version` prints
   the version from `LintableCommand`, `0.1.0-dev` for now; phase 5 sets it from
   the release tag.
3. **`LICENSE`.** MIT, "Copyright (c) 2026 the Lintable authors".
4. **`CONTRIBUTING.md`.** How to build, test and lint; the conventions below;
   how to propose a rule (open a rule proposal issue first); the checklist a
   rule needs before it merges (spec, options with defaults, examples, tests,
   docs page, validated on a real codebase).
5. **`CODE_OF_CONDUCT.md`** (Contributor Covenant 2.1), **`SECURITY.md`** (report
   through GitHub's private vulnerability reporting), **`CHANGELOG.md`** (Keep a
   Changelog format, an `Unreleased` section).
6. **Issue templates.** A bug report (version, config, the code, what was
   reported, what was expected), and a rule proposal (what it catches, why it
   needs structure, what to do instead, examples, likely false positives).
7. **Conventions** (written in `CONTRIBUTING.md`, checked by `.swiftlint.yml`):
   - no comments in Swift code. Only `// swiftlint:` and `// lintable:`
     directives are allowed;
   - public API is documented in each target's DocC catalog
     (`Sources/<Target>/<Target>.docc`), with articles and symbol extension
     files, not in source comments;
   - no force unwraps or force casts outside tests;
   - Swift Testing for every test.
8. **`.swiftlint.yml`.** A `no_comments` custom rule whose lookahead allows
   `swiftlint:` and `lintable:` directives, plus the opt-in rules that match the
   conventions above. SwiftLint runs in CI, not as a package plugin.
9. **CI** (`.github/workflows/ci.yml`), on pull requests and pushes to `main`:
   - macOS (the newest Xcode with Swift 6.x): `swift build`, `swift test`,
     `swiftlint lint --strict`;
   - Linux (`swift:6.x` image): `swift build`, `swift test`.
10. **`README.md`.** Keep the status line ("design") until 0.1.0; link
    `CONTRIBUTING.md`.

The repository's visibility on GitHub is Peter's call. Push the branch and open
the pull request; don't change settings on the GitHub repository.

## Verify

```bash
swift build
```

```bash
swift test
```

```bash
swift run lintable version
```

```bash
swiftlint lint --strict
```

CI is green on the pull request on both platforms.

## Done

The skeleton builds and tests on macOS and Linux, lints clean, prints its
version, and the open-source files are in place. One commit.
