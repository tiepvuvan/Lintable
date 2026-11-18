# Lintable: design and build plan

This folder is the plan for building Lintable, written for the agents and people
who will build it. Start here, then read [architecture.md](architecture.md) and
[facts.md](facts.md).

## What Lintable is

A linter for Swift rules that need code structure: the function, initializer,
accessor or closure around a line, the type it's in, what it inherits from, and
who calls what in the file. It parses with swift-syntax. It does not do style or
formatting; SwiftLint and swift-format already do that well, and Lintable runs
next to them.

A rule belongs in Lintable when:
- it needs structure that a line-based regex can't see reliably;
- its rationale fits in a paragraph, with a clear "do this instead";
- it has few false positives on real code, and the ones it has can be explained
  and suppressed with a reason;
- its defaults suit most projects, and options cover the rest.

## Decisions (Peter, 2026-11-18)

- **Open source, MIT**, at `github.com/tiepvuvan/Lintable`.
- **Complements SwiftLint.** No style or regex rules. Directives use their own
  `lintable:` prefix, so they never clash with `swiftlint:` ones.
- **Custom rules are Swift packages.** The rule API is a public library. A
  project writes rules in its own package and builds its own small linter that
  combines them with the built-in rules. The built-in rules alone ship as a
  prebuilt binary, which is all most projects need.
- **The first rule is `layout_lifecycle`**: views get geometry only during
  layout. Spec: [rules/layout_lifecycle.md](rules/layout_lifecycle.md).
- **Habitify is the first adopter.** Its codebase is the real-world test for
  the first rule. It adopts Lintable once 0.1.0 is ready; its adoption plan is
  kept privately, outside this repo.

Decisions made while designing, which Peter can still change:
- Rules are opt-in: a project lists the rules it wants. Installing the plugin
  without a config does nothing.
- macOS and Linux, so the CLI runs in Linux CI. No Windows.
- The code follows the same conventions as Habitify: no comments in Swift code,
  documentation in DocC catalogs (articles and symbol extension files), SwiftLint
  in CI.
- The plugin and its binary ship from a second, small repo,
  `tiepvuvan/LintablePlugins`, the way SwiftLint ships `SwiftLintPlugins`, so
  adopters don't download swift-syntax's sources to use the plugin.

## Phases

| Phase | Doc | What | Depends on | Release | Status (2026-11-18) |
|---|---|---|---|---|---|
| 0 | [phase-0-foundation.md](phase-0-foundation.md) | Package skeleton, license, CI, contributor docs | — | | Built; CI on macOS (Swift 6.1.2) and Linux (Swift 6.4) |
| 1 | [phase-1-kit.md](phase-1-kit.md) | `LintableKit`: the rule API and the syntax index rules share | 0 | | Built, 26 tests |
| 2 | [phase-2-engine.md](phase-2-engine.md) | `LintableEngine` and the CLI: config, directives, reporters, baseline, cache | 1 | | Built, 52 tests |
| 3 | [phase-3-testing.md](phase-3-testing.md) | `LintableTesting`: the rule test harness, example checks, generated rule docs | 2 | | Built, 7 tests |
| 4 | [phase-4-layout-rule.md](phase-4-layout-rule.md) | `layout_lifecycle`, validated on Habitify | 3 | | Built, 28 tests, validated |
| 5 | [phase-5-release.md](phase-5-release.md) | Build-tool and command plugins, the release pipeline, `LintablePlugins` | 4 | 0.1.0 | Built and smoke-tested on macOS; release steps need Peter |
| 6 | [phase-6-custom-rules.md](phase-6-custom-rules.md) | Custom rule packages: template, source-built plugin, guide | 5 | 0.2.0 | Not started |

The phases run in order: each builds on the one before. Lintable is built
first; Habitify adopts it after 0.1.0.

After 0.2.0: [roadmap.md](roadmap.md).

## For every phase

1. Read this file, [architecture.md](architecture.md) and [facts.md](facts.md).
   Facts marked "assumed" are yours to confirm; update facts.md with what you
   find.
2. Follow the conventions from phase 0: Swift 6 language mode, strict
   concurrency, no comments in Swift code, public API documented in the DocC
   catalog.
3. Every public type and function gets a DocC entry. Every behavior gets a test.
4. One commit per phase, on a branch, merged by pull request.
5. Done means: `swift build` and `swift test` pass on macOS and Linux (CI is
   green), `swiftlint lint --strict` is clean, and the phase's own checks pass.
