# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org).

## Unreleased

### Added

- `LintableKit`: the rule API (`Rule`, `RuleOptions`, `RuleDescription`, `Example`,
  `Violation`, `RulePack`) and `SyntaxIndex`, which answers scopes, signatures,
  enclosing types, inheritance, calls, references, closure invocations, assignment
  targets and local variables for one file.
- `LintableEngine`: `.lintable.yml` configuration, file discovery with `**` globs,
  parallel linting, `// lintable:` directives with required reasons, baselines, a
  per-file cache, and the `xcode`, `summary`, `json`, `sarif` and `github` reporters.
- `lintable` CLI: `lint`, `baseline`, `rules`, `explain`, `docs`, `init`, `version`.
- `LintableTesting`: `assertLint` and `verifyExamples(of:)` for rule tests.
- The first rule, `layout_lifecycle`: views get geometry only during layout.
