# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org).

## Unreleased

## 0.3.0 - 2026-11-20

### Added

- Localization rules for Swift code: `hardcoded_ui_text` (a literal reaches a label,
  title, alert or accessibility label without being localized), `english_plural_logic`
  (`count == 1 ? "day" : "days"`), `number_as_text_in_localized_string` (a count
  turned into text inside a localized string, which can't vary by plural) and
  `localized_concatenation` (text built by joining localized pieces).
- `missing_translator_comment`: a String Catalog key with no comment for translators.

## 0.2.0 - 2026-11-20

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
