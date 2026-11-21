# Custom rules

A project can write its own rules and run them in its builds next to Lintable's. The
rules live in a small Swift package that builds a linter: Lintable's command-line tool
plus your rule pack, with the same config, directives, reporters and baseline.
[`Templates/CustomLinter`](../Templates/CustomLinter) is a working one to copy.

## Your project or Lintable?

Keep a rule in your project when it encodes your conventions: your logger, your base
classes, your module boundaries, a rule about code only your team writes. Propose it
upstream, with a [rule proposal issue](https://github.com/tiepvuvan/Lintable/issues/new/choose),
when it catches a mistake any Swift project can make. A built-in rule needs structure
that a line-based regex can't see, a clear "do this instead", few false positives on
real code, and defaults that suit most projects; [CONTRIBUTING.md](../CONTRIBUTING.md)
has the checklist.

## The template

```
CustomLinter/
  Package.swift
  .lintable.yml
  Sources/AcmeRules/             the rule pack and its rules
  Sources/acme-lint/main.swift   the linter: Lintable's rules plus yours
  Tests/AcmeRulesTests/          tests written with LintableTesting
  Plugins/AcmeLintSourcePlugin/  runs acme-lint from source in builds
  AcmeLintPlugins/               a separate package with the prebuilt-binary plugin
```

Copy the folder into your repository, for example as `AcmeLint/`, and rename `Acme` to
your project's name in file names, types and the executable. The example rule,
`no_print_in_views`, reports `print` inside a `UIView` subclass.

The linter itself is three lines:

```swift
import AcmeRules
import LintableCommand
import LintableRules

await LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])
```

Leave out `BuiltInRules` to ship only your rules. Every Lintable command works with the
loaded packs:

```bash
swift run acme-lint rules
```

```bash
swift run acme-lint explain no_print_in_views
```

```bash
swift run acme-lint docs --output docs/rules
```

## Writing a rule

A rule is a type that conforms to `Rule` (Swift files) or `CatalogRule` (String
Catalogs), with a static `description`, an `init(options:)` and a `check` function.

**Describe it.** `RuleDescription` holds what Lintable shows about the rule:

- `id`: snake_case, unique across every pack the linter loads; the registry refuses
  duplicates.
- `name`, `summary` and `rationale`: what the rule catches and why it matters.
- `category`: your own, such as `RuleCategory(id: "acme", name: "Acme conventions")`.
- `defaultSeverity`: what the rule reports at when the config doesn't say.
- `optionDescriptions`: one line per option, keyed by its snake_case name.
- `triggeringExamples` and `nonTriggeringExamples`: source with `1️⃣`, `2️⃣`, … where
  violations are expected. They are the rule's documentation page and its first tests.
- `howToFix`: the fix, in a sentence or two.
- `documentationURL`: where reports link the rule. It defaults to Lintable's rule
  pages, so set it to your own.

**Give it options.** Options are a `RuleOptions` struct whose properties all have
defaults. Lintable decodes the rule's section of `.lintable.yml` into it, with
snake_case keys, and refuses unknown keys:

```yaml
rules:
  no_print_in_views:
    severity: error
    view_classes: [UIView, NSView, CardView]
```

**Check a file.** `check(_:)` receives a `LintFile`. Ask its `index` about the file:
`calls(named:)`, `types(of:)` and `inheritsFrom(_:anyOf:)`, `scope(of:)` and
`scopes(of:)`, `assignmentTarget(of:)`, `invocation(of:)`. For anything else, walk
`file.tree` with a swift-syntax `SyntaxVisitor`, as Lintable's own rules do. The
index looks at one file at a time, so a rule that needs to know about types declared
elsewhere takes them as an option, the way `view_classes` does.

**Write the message for the reader.** Say what is wrong, where, and what to do instead:
"`print` in `render()` of `ChartView` writes to the console every time the view runs it,
in release builds too. Log through the app's logger instead." Report at the node the
reader should look at. Lintable turns positions into lines and columns, applies
`// lintable:` directives and formats the output.

Rules run on many files in parallel, so they must not keep mutable state.

**String Catalog rules** conform to `CatalogRule`, receive a parsed `StringCatalog`, and
go in the pack's `catalogRules`.

**Group them in a pack.**

```swift
public enum AcmeRules: RulePack {
    public static let name = "AcmeRules"
    public static let version = "1.0.0"
    public static let rules: [any Rule.Type] = [NoPrintInViewsRule.self]
}
```

## Testing it

`LintableTesting` runs a rule through the engine, so directives apply, and records a
Swift Testing issue at your test's line for every missing, extra or misplaced
violation:

```swift
@Test func examplesAreCorrect() {
    verifyExamples(of: NoPrintInViewsRule.self)
}

@Test func viewClassesOption() {
    assertLint(NoPrintInViewsRule.self, options: "view_classes: [CardView]", """
    final class StatsCard: CardView {
        func update() {
            1️⃣print("update")
        }
    }
    """)
}
```

`verifyExamples(of:)` checks that triggering examples report exactly at their markers,
that non-triggering examples report nothing, that a `disable:next` directive before
each marked line silences it, and that every example parses. `assertLint` also takes
`messages:` to check the text, and `assertCatalogLint` does the same for catalog rules.

```bash
swift test
```

## Running it in builds

The config is a `.lintable.yml` like Lintable's, and it enables rules from both packs.
Both plugins use the nearest one from the target's folder up to the package or project
root, and do nothing without one.

### From source

Add the package and its `AcmeLintSourcePlugin` to the targets you want checked:

```swift
dependencies: [
    .package(path: "AcmeLint"),
],
targets: [
    .target(
        name: "App",
        plugins: [.plugin(name: "AcmeLintSourcePlugin", package: "AcmeLint")]
    ),
]
```

In an Xcode project, add `AcmeLint` as a local package, then add
`AcmeLintSourcePlugin` under each target's Build Phases → Run Build Tool Plug-ins.

A tool built from source can't run as a prebuild command, so this plugin returns a build
command. Its inputs are the target's Swift files and String Catalogs and the config, and
its output is `AcmeLintReleaseGate.swift`, so it runs again only when one of them
changes. The trade-off is the build: every clean build compiles swift-syntax and
Lintable along with your project, unless SwiftPM has a prebuilt swift-syntax for your
toolchain. That takes seconds on a Mac with one and several minutes on a CI runner
without.

### Prebuilt

Release the linter as an artifact bundle and use a plugin that downloads it, the way
`LintablePlugins` ships Lintable. Lintable's scripts take the product and the package:

```bash
script/build-binary.sh --product acme-lint --package-path AcmeLint dist
```

```bash
script/assemble-artifact-bundle.sh --product acme-lint --license AcmeLint/LICENSE 1.0.0 dist release
```

The first builds a universal binary on macOS (run it on Linux for the Linux variants,
which link the Swift runtime statically). The second writes
`release/acme-lint.artifactbundle.zip` and its checksum. The bundle's artifact is
named `acme-lint-cli`, not `acme-lint`: Swift 6.1's `swift build` refuses a prebuild
command whose executable has the same name as a tool the plugin can use, so the
plugin asks for `acme-lint-cli`. Without `--license`, the bundle carries Lintable's
license, which the binary includes.

Attach the zip to a release, then write the package projects add, with its binary target
pointing at the release asset:

```bash
script/make-plugins-package.sh --plugins-package AcmeLint/AcmeLintPlugins --binary-target AcmeLintBinary https://example.com/acme-lint/releases/download/1.0.0/acme-lint.artifactbundle.zip <checksum> AcmeLintPluginsRelease
```

Publish that folder as its own repository and tag it. Projects add it and
`AcmeLintBinaryPlugin`, and adding it downloads one zip. To try the plugin before a
release, copy `release/acme-lint.artifactbundle` to
`AcmeLint/AcmeLintPlugins/AcmeLintBinary.artifactbundle` and depend on
`AcmeLintPlugins` by path.

| | From source | Prebuilt |
|---|---|---|
| Setup | Add the package | Release a bundle and a plugins package |
| Clean build | Compiles swift-syntax and Lintable | Downloads one zip |
| Runs | When the target's files or the config change | Before every build, with Lintable's cache |
| Rule changes | Take effect on the next build | Need a new release |

Use one of the two in a target, and not `LintablePlugins` as well: the linter already
runs Lintable's rules.

## Keeping up with Lintable

The template depends on `.package(url: "https://github.com/tiepvuvan/Lintable", from: "0.4.0")`.
Lintable is before 1.0, so a minor release can change the rule API; read the
[changelog](../CHANGELOG.md) before raising the version, and run your tests.

To build against a local Lintable checkout, set `LINTABLE_LOCAL_PATH`:

```bash
LINTABLE_LOCAL_PATH=~/src/Lintable swift test
```

SwiftPM names a path dependency after its folder, so the folder must be called
`Lintable`. Lintable's CI tests the template this way, with
[`script/custom-linter-smoke-test.sh`](../script/custom-linter-smoke-test.sh).
