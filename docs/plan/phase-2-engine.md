# Phase 2: the engine and the CLI

Build `LintableEngine` and `LintableCommand`: everything between "here are some
files and rules" and "here is the output and the exit code".

Read first: [architecture.md](architecture.md), from "The engine" to "CLI
commands".

## Files

```
Sources/LintableEngine/
  Configuration/Configuration.swift
  Configuration/RuleConfiguration.swift
  Discovery/FileDiscovery.swift
  Discovery/Glob.swift
  Registry/RuleRegistry.swift
  Runner/Runner.swift
  Directives/Directive.swift
  Directives/DirectiveParser.swift
  Baseline/Baseline.swift
  Cache/Cache.swift
  Reporters/Reporter.swift
  Reporters/XcodeReporter.swift
  Reporters/SummaryReporter.swift
  Reporters/JSONReporter.swift
  Reporters/SARIFReporter.swift
  Reporters/GitHubReporter.swift
  LintableEngine.docc/
Sources/LintableCommand/
  LintableCommand.swift
  LintCommand.swift
  BaselineCommand.swift
  RulesCommand.swift
  InitCommand.swift
  VersionCommand.swift
Tests/LintableEngineTests/
```

## Steps

1. **Registry.** Takes rule packs, refuses duplicate IDs, and builds a rule
   instance from a rule's config section by decoding its `Options` (opening the
   existential `any Rule.Type`). Unknown option keys and wrong types are config
   errors naming the rule and the key.
2. **Configuration.** Decode `.lintable.yml` with Yams: `included`, `excluded`,
   `baseline`, `require_reasons`, `rules`. Unknown top-level keys are errors.
3. **Discovery.** Expand paths and globs relative to the config file; accept an
   explicit list (`--files-from`). Skip non-Swift files; follow no symlinks out
   of the root.
4. **Runner.** A task group with at most one task per active processor. Per
   file: read, cache lookup, `LintFile`, enabled rules, directives, cache store.
   A rule that traps can't be caught; a rule that returns a violation outside the
   file is an internal error with the rule's ID.
5. **Directives.** Parse `// lintable:` comments from trivia: `disable:next`,
   `disable:this`, `disable` … `enable`, comma-separated IDs, ` - reason`. Apply
   them per file. Report `unknown_rule`, `missing_reason` and
   `superfluous_directive` as engine violations (warnings, configurable under
   their own IDs in `rules:`).
6. **Baseline.** Write and read the format in architecture.md, match entries as
   described there, and keep the file sorted so diffs stay small.
7. **Cache.** One file per Swift file under `--cache-path`, named by a hash of
   its path; the key from architecture.md inside. A corrupt entry is ignored and
   rewritten.
8. **Reporters.** The five in architecture.md. SARIF includes rule metadata
   (`tool.driver.rules`) with summaries and help URIs.
9. **Commands.** `lint`, `baseline`, `rules`, `init`, `version` with
   swift-argument-parser, and the public entry
   `LintableCommand.main(rulePacks:)`. `lintable` calls it with
   `[LintableRules.self]`. Exit codes as in architecture.md.

## Tests

Use a test-only rule pack (a rule that flags identifiers named `forbidden`) so
the engine is tested without the real rules:

- Config: valid file; unknown key; bad severity; unknown option for a rule; a
  rule listed that isn't loaded.
- Discovery: `included` and `excluded` globs, `**`, an explicit file list.
- Directives: each form; several IDs; a missing reason with and without
  `require_reasons`; an unknown ID; a superfluous directive; a region left open
  to the end of the file.
- Baseline: matching after lines move, a second identical line reported,
  entries consumed once.
- Cache: a hit with nothing changed; a miss after the file, the config or the
  tool version changes.
- Reporters: golden-file output for each, from the same set of violations.
- CLI end to end: run the `lint` command in-process on a fixture directory and
  check output and exit code, including `--strict`.
- Determinism: the same input gives byte-identical output across runs.

## Verify

```bash
swift test --filter LintableEngineTests
```

```bash
swift run lintable lint --config Tests/Fixtures/Basic/.lintable.yml Tests/Fixtures/Basic
```

## Done

`lintable lint` works end to end with a test rule pack, all reporters, the
baseline and the cache are tested, CI is green. One commit.
