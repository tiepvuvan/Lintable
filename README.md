# Lintable

Architecture rules for Swift: rules that need to know where code is, not just
what it says.

SwiftLint is great at style: what a line looks like. Some rules need more than a
line. "Set a view's frame only during layout" depends on which function the line
is in, what calls that function, and which class it belongs to. Lintable parses
Swift with [swift-syntax](https://github.com/swiftlang/swift-syntax), gives every
rule the structure around each line, and makes rules like that easy to write,
test and share.

Lintable also checks String Catalogs: missing translations, plural forms and
placeholders, which Xcode shows but never enforces.

Lintable runs next to SwiftLint, not instead of it.

> **Status: 0.2.0.** The rules are
> [`layout_lifecycle`](docs/rules/layout_lifecycle.md) and six localization rules
> for String Catalogs, and [Habitify](https://www.habitify.me) is the first project
> adopting them. The design and build plan are in [docs/plan](docs/plan/README.md).

## Rules

| Rule | Checks |
|---|---|
| [`layout_lifecycle`](docs/rules/layout_lifecycle.md) | Views get geometry only during layout: `frame`, `bounds`, `center` or a layer's `position` are set in `layoutSubviews()` and its relatives, not in gesture handlers, callbacks or setters. |
| [`missing_translation`](docs/rules/missing_translation.md) | A string has no finished translation in one of the String Catalog's languages. |
| [`placeholder_mismatch`](docs/rules/placeholder_mismatch.md) | A translation's format specifiers don't match the source string's. |
| [`missing_plural_form`](docs/rules/missing_plural_form.md) | A plural variation lacks a form its language needs. |
| [`plural_form_without_number`](docs/rules/plural_form_without_number.md) | A plural form is used for several numbers but doesn't show the number. |
| [`number_without_plural`](docs/rules/number_without_plural.md) | An English source string counts something without varying by plural. |
| [`stale_string`](docs/rules/stale_string.md) | A String Catalog keeps a string the code no longer uses. |

Rules are opt-in: a project lists the ones it wants in `.lintable.yml`.

## Use it

Lintable needs Swift 6.1 or later (Xcode 16.3 or later), and runs on macOS 13 or
later and on Linux (x86_64 and aarch64).

Add the plugin to a Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/tiepvuvan/LintablePlugins", from: "0.2.0"),
],
targets: [
    .target(
        name: "App",
        plugins: [.plugin(name: "LintableBuildToolPlugin", package: "LintablePlugins")]
    ),
]
```

In an Xcode project, add the same package and turn on `LintableBuildToolPlugin` under
each target's **Build Phases → Run Build Tool Plug-ins**. The plugin runs a prebuilt
binary, so builds don't compile swift-syntax.

Then add `.lintable.yml` at the package or project root:

```yaml
excluded:
  - "**/Tests/**"
rules:
  layout_lifecycle:
    severity: error
```

Violations show up in Xcode and fail the build:

```
Sources/Chart/ChartView.swift:42:9: error: `center.x` is set in `handlePan(_:)`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper. (layout_lifecycle)
```

## String Catalogs

The plugin also reads each target's `.xcstrings` files, and the localization rules
check them:

```yaml
release_condition: "!DEBUG"
rules:
  missing_translation:
    severity: warning
    release_severity: error
  placeholder_mismatch:
  missing_plural_form:
  plural_form_without_number:
  number_without_plural:
  stale_string:
```

A rule whose `release_severity` is above its `severity` reports as usual, and stops
the builds where `release_condition` holds: the plugin writes
`LintableReleaseGate.swift` into the target, and while such a rule reports
violations the file holds an `#error` inside `#if !DEBUG`. Debug builds warn about a
new untranslated string; Release builds and archives stop until it's translated.
`lintable lint --release-gate <path>` writes the same file.

The plural rules use the CLDR plural rules for whole numbers, and know that
Foundation uses a `zero` form for 0 in every language.

## The command line

```bash
lintable lint
```

```bash
lintable lint --reporter sarif > lintable.sarif
```

```bash
lintable explain layout_lifecycle
```

| Command | Does |
|---|---|
| `lint` | Check the config's `included` paths, or the files and folders given |
| `baseline` | Record the current violations so `lint` reports only new ones |
| `rules` | List the loaded rules and which the config enables |
| `explain <rule>` | Show a rule's rationale, options, fixes and examples |
| `docs` | Write a Markdown page per rule |
| `init` | Write a starter `.lintable.yml` |

Reporters: `summary` (in a terminal), `xcode` (elsewhere), `json`, `sarif` and
`github`. Exit codes: 0 clean, 1 errors (or warnings with `--strict`), 2 config or
usage errors, 3 internal errors.

## Exceptions

```swift
// lintable:disable:next layout_lifecycle - the snapshot follows the system's transition frames
snapshot.frame = finalFrame
```

`disable:next`, `disable:this` at the end of a line, and `disable` … `enable` regions.
A reason after ` - ` is required unless the config sets `require_reasons: false`.
Lintable reports directives that suppress nothing, name an unknown rule, or have no
reason. Projects that ban comments must allow `// lintable:` the way they allow
`// swiftlint:`.

## Your own rules

The rule API is a public Swift library. Write rules with `LintableKit`, test them with
`LintableTesting`, and build a small linter that runs them next to the built-in rules:

```swift
import AcmeRules
import LintableCommand
import LintableRules

await LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])
```

A template package and guide arrive in 0.3.0.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Lintable is MIT-licensed.
