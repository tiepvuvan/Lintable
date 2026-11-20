# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org).

## Unreleased

### Added

- Localization rules for String Catalogs: `missing_translation`, `placeholder_mismatch`,
  `missing_plural_form`, `plural_form_without_number`, `number_without_plural` and
  `stale_string`, with the CLDR plural rules for whole numbers in about 200 languages.
- `LintableKit`: `CatalogRule`, `StringCatalog`, `PluralRules`, `FormatSpecifier` and
  `RulePack.catalogRules`; `LintableTesting`: `assertCatalogLint` and `verifyExamples(of:)`
  for catalog rules.
- `release_condition` and a per-rule `release_severity` in `.lintable.yml`, and
  `lint --release-gate <path>`, which writes a Swift file whose `#error` stops builds
  where the condition holds while such a rule reports violations. The build plugin
  writes it into every target.

### Changed

- File discovery, `--files-from` and both plugins include `.xcstrings` files.

## 0.1.0 - 2026-11-19

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
- `LintablePlugins`: a build-tool plugin and a command plugin that run a prebuilt
  binary.
