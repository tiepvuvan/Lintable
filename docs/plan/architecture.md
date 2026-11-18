# Architecture

```
Swift files ─▶ parse (SwiftParser) ─▶ LintFile + SyntaxIndex ─▶ rules ─▶ directives ─▶ baseline ─▶ reporter
                     ▲                                          ▲
               cache (per file)                        rule packs + config
```

Each file is parsed once. Its `SyntaxIndex` (scopes, types, calls) is built
lazily, once per file, and shared by every rule that runs on it. Files are
checked in parallel. Output is sorted, so runs are deterministic.

## Repositories and targets

**`tiepvuvan/Lintable`**, the source:

| Target | Kind | Depends on | Role |
|---|---|---|---|
| `LintableKit` | library | SwiftSyntax, SwiftParser | The rule API and the syntax index. Rule authors import only this. |
| `LintableEngine` | library | LintableKit, Yams | Config, file discovery, the runner, directives, baseline, cache, reporters. |
| `LintableCommand` | library | LintableEngine, ArgumentParser | The CLI as a library: `LintableCommand.main(rulePacks:)`. Custom linters call it. |
| `LintableRules` | library | LintableKit | The built-in rule pack, `BuiltInRules`. Starts with `layout_lifecycle`. |
| `LintableTesting` | library | LintableKit, LintableEngine | The rule test harness, for Lintable and for custom rule packs. |
| `lintable` | executable | LintableCommand, LintableRules | The official linter: built-in rules only. |

Products: the five libraries and the `lintable` executable. The package exports
no plugin, so depending on it never attaches anything by accident.

**`tiepvuvan/LintablePlugins`**, what most projects add. Its source lives in this repo's
`LintablePlugins/` folder, where the binary target points at a locally built bundle
(`LintableBinary.artifactbundle`, not committed); the release workflow publishes a copy
whose binary target points at the release asset. It needs swift-tools-version 6.1, for
the plugin API's `Target.directoryURL`.

- `.binaryTarget(name: "LintableBinary", url: <release asset>, checksum: <sha256>)`.
- `LintableBuildToolPlugin`: a `BuildToolPlugin` and an `XcodeBuildToolPlugin`.
- `LintableCommandPlugin`: a `CommandPlugin` and an `XcodeCommandPlugin`
  (`swift package lintable`, and a menu item in Xcode).

It has no source dependencies, so adding it downloads one zip. The release
pipeline (phase 5) writes its URL and checksum and tags it with the same version
as Lintable.

## The rule API (`LintableKit`)

```swift
public protocol Rule: Sendable {
    associatedtype Options: RuleOptions = NoOptions
    static var description: RuleDescription { get }
    init(options: Options)
    func check(_ file: LintFile) -> [Violation]
}

public protocol RuleOptions: Codable, Sendable, Equatable {
    init()
}

public struct NoOptions: RuleOptions {
    public init() {}
}

public struct RuleDescription: Sendable {
    public var id: RuleID
    public var name: String
    public var summary: String
    public var rationale: String
    public var category: RuleCategory
    public var defaultSeverity: Severity
    public var optionDescriptions: [String: String]
    public var triggeringExamples: [Example]
    public var nonTriggeringExamples: [Example]
    public var howToFix: String
}

public struct Violation: Sendable, Hashable {
    public var position: AbsolutePosition
    public var message: String
    public var notes: [Note]
}

public protocol RulePack: Sendable {
    static var name: String { get }
    static var rules: [any Rule.Type] { get }
}
```

- `RuleID` is a `snake_case` string, unique across all loaded packs. The engine
  refuses to start when two rules share an ID.
- A rule returns `Violation`s with positions. The engine adds the rule's ID, the
  configured severity, and the line and column, so rules never format output.
  Messages don't carry links; the JSON and SARIF reporters add each rule's
  documentation URL, and `lintable explain` prints the page.
- `Options` decode from the rule's section of the config. Every field has a
  default, so `init()` is the rule's default configuration, and an unknown key is
  a config error.
- `Example` is source text with markers (`1️⃣`, `2️⃣`, …) where violations are
  expected, the convention swift-syntax uses in its own tests. Examples are the
  rule's documentation and its first tests at once.
- Rules hold no mutable state and must be `Sendable`: one instance checks many
  files in parallel.

A rule usually walks the tree with a `SyntaxVisitor` and asks the index about
what it finds:

```swift
public struct LintFile: Sendable {
    public let path: String
    public let tree: SourceFileSyntax
    public let index: SyntaxIndex
}
```

## The syntax index

Lazily built facts about one file, shared by its rules. This is what makes
"which function is this line in" cheap and consistent across rules:

| Query | Answer |
|---|---|
| `scope(of: node)` | The innermost function, initializer, deinitializer, accessor (`get`, `set`, `didSet`, …), closure or top level around a node |
| `scopes(of: node)` | The whole chain, innermost first |
| `function(_:)` | A function's signature: base name, argument labels, `override`, `static`, access level, attributes (`@objc`, …) |
| `types(of: node)` | The enclosing types, innermost first: kind (class, struct, enum, actor, extension), name, inheritance clause |
| `inheritsFrom(_:anyOf:)` | Whether a class's inheritance clause names one of the given types, directly or through a class declared in the same file |
| `calls(to: signature)` | The call sites in the file whose callee matches a base name and labels (`f(…)`, `self.f(…)`, `x.f(…)`) |
| `references(to: signature)` | Non-call uses: `#selector(f)`, `f` passed as a value |
| `invocation(of: closure)` | For a closure argument, the call it's passed to, as a dotted name (`DispatchQueue.main.async`) |
| `assignmentTarget(of: expr)` | For an assignment, the left side as a member chain: root, members, and whether the root is `self` (explicit or implicit) |
| `localVariable(named:at:)` | Whether a name refers to a local `var` or `let` declared earlier in the same scope |

Everything is syntactic: no type checking, no cross-file lookup. A rule's docs
say what that means for it (a property named `frame` on a model type looks like a
view's).

## The engine

```
lintable lint [paths…] [--config <file>] [--reporter <name>] [--baseline <file>] [--cache-path <dir>] [--files-from <file>]
```

1. **Config.** Load `.lintable.yml` from the current directory, or the one given.
   Instantiate the enabled rules with their decoded options. A config error stops
   the run with exit code 2.
2. **Files.** Use the files given (`--files-from` takes a file with one path per
   line, which the plugin uses), or walk the paths under `included`. `excluded`
   globs apply either way, so a test target's files are skipped even when the
   plugin passes them. Skip files that aren't `.swift`.
3. **Check.** In parallel, per file: read it, look it up in the cache, otherwise
   parse it, build its `LintFile`, run every enabled rule, apply the file's
   directives, and store the result.
4. **Baseline.** Drop violations recorded in the baseline.
5. **Report.** Sort by path, line, column and rule ID, and print with the chosen
   reporter.
6. **Exit.** 0 when no violation has severity `error`; 1 when one does; 2 for a
   config or usage error; 3 for an internal error. `--strict` treats warnings as
   errors.

The engine adds its own checks, reported under reserved IDs: `unknown_rule` (a
directive names a rule that isn't loaded), `missing_reason` (a directive without
a reason, when reasons are required), `superfluous_directive` (a directive that
suppresses nothing).

## Configuration

```yaml
included:
  - Sources
excluded:
  - "**/Tests/**"
  - "**/*.generated.swift"
baseline: .lintable-baseline.json
require_reasons: true
rules:
  layout_lifecycle:
    severity: error
    exempt_transitions: true
```

- Rules are opt-in: only rules listed under `rules:` run. A rule's section takes
  `severity` (`error` or `warning`) plus the rule's own options.
- Paths are relative to the config file. Globs follow `fnmatch` with `**`.
- `lintable init` writes a starter config listing every built-in rule.

## Directives

```swift
// lintable:disable:next layout_lifecycle - the snapshot follows the system's transition frames
snapshot.frame = finalFrame
```

- `// lintable:disable:next <ids> - <reason>`: the next line.
- `// lintable:disable:this <ids> - <reason>`: at the end of a line, that line.
- `// lintable:disable <ids> - <reason>` … `// lintable:enable <ids>`: a region.
- `<ids>` is one or more rule IDs, comma-separated. `all` is not accepted: a
  directive says which rule it silences.
- The reason is required by default (`require_reasons: false` turns that off).

Projects that ban comments, like Habitify's SwiftLint `no_comments` rule, must
allow `// lintable:` the way they allow `// swiftlint:`.

## Reporters

| Name | Output | For |
|---|---|---|
| `xcode` | `path:line:col: error: message (rule_id)` | Xcode and the plugin |
| `summary` | Violations grouped by file, then counts per rule | People at a terminal (the default when stdout is a TTY) |
| `json` | An array of violations with path, line, column, rule, severity, message | Scripts |
| `sarif` | SARIF 2.1.0 | GitHub code scanning |
| `github` | `::error file=…,line=…,col=…::message` | GitHub Actions annotations |

## Baseline

`lintable baseline` writes `.lintable-baseline.json`: for each violation, the rule
ID, the file path relative to the config, the trimmed text of the line, and the
message. `lint --baseline` drops violations that match an entry, each entry
consuming one match, so moving code around doesn't resurface old violations, but
a new copy of the same line does. A baseline only ever shrinks by hand: the tool
never adds to an existing one during `lint`.

## Cache

Keyed by the tool version, a fingerprint of the loaded rule packs (rule IDs and
pack versions), the normalized config, and the file's content hash. The value is
the file's violations after directives. The plugin passes `--cache-path` inside
its work directory, so a rebuild with no changed files only hashes them.

## CLI commands

| Command | Does |
|---|---|
| `lint` | Check files (above) |
| `baseline` | Record the current violations |
| `rules` | List loaded rules: ID, category, default severity, whether the config enables it |
| `explain <id>` | Print a rule's summary, rationale, options and examples |
| `docs --output <dir>` | Write a Markdown page per rule and an index |
| `init` | Write a starter config |
| `version` | Print the version |

## Plugins

The build-tool plugin returns a prebuild command (which needs a binary tool,
hence the binary target):

- `lintable lint --reporter xcode --files-from <list> --cache-path <work dir>`;
- the list is the target's Swift files, written to the plugin work directory;
- the config is the nearest `.lintable.yml` found walking up from the target's
  directory to the package or project root. With none, the plugin does nothing.

The command plugin runs `lint` on the whole package, or on the targets chosen in
Xcode's menu.

## Distribution

- **Artifact bundle.** Each release builds `lintable` for macOS (arm64 and
  x86_64, one universal binary) and Linux (x86_64 and aarch64, with the Swift
  standard library linked statically) and zips them as
  `lintable.artifactbundle.zip`:

  ```json
  {
    "schemaVersion": "1.0",
    "artifacts": {
      "lintable-cli": {
        "type": "executable",
        "version": "0.1.0",
        "variants": [
          { "path": "lintable-macos/bin/lintable", "supportedTriples": ["arm64-apple-macosx", "x86_64-apple-macosx"] },
          { "path": "lintable-linux-x86_64/bin/lintable", "supportedTriples": ["x86_64-unknown-linux-gnu"] },
          { "path": "lintable-linux-aarch64/bin/lintable", "supportedTriples": ["aarch64-unknown-linux-gnu"] }
        ]
      }
    }
  }
  ```

  The artifact is named `lintable-cli`, not `lintable`. Swift 6.1's
  `swift build` refuses a prebuild command whose executable has the same file
  name as any tool the plugin can use, prebuilt ones included, calling it
  "built from source" ([swift-package-manager#8440](https://github.com/swiftlang/swift-package-manager/pull/8440)
  fixed it in later releases). A tool name that differs from the binary's
  name keeps the build-tool plugin working there.

- **GitHub release** of `Lintable` with the zip, its checksum, and the binaries
  as plain downloads for CI.
- **`LintablePlugins`** updated to the new URL and checksum, and tagged.
- [Mint](https://github.com/yonaskolb/Mint) works from the source repo with no
  extra work (`mint run tiepvuvan/Lintable`). Homebrew comes later.

## Custom rules

A project that wants its own rules creates a package:

```
AcmeLint/
  Package.swift
  Sources/AcmeRules/
  Sources/acme-lint/main.swift
  Tests/AcmeRulesTests/
  Plugins/AcmeLintPlugin/
```

```swift
import AcmeRules
import LintableCommand
import LintableRules

@main
struct AcmeLint {
    static func main() async {
        await LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])
    }
}
```

The executable is the official CLI plus the project's rules: same config,
directives, reporters and baseline. Two ways to run it in builds:

- **From source**: a small build-tool plugin in the project's package, which
  returns a build command (a source-built tool can't run as a prebuild command)
  with the target's files as inputs and a stamp file as output. Simple, but every
  clean build compiles swift-syntax.
- **Prebuilt**: the project releases its linter as its own artifact bundle with
  Lintable's release script, and uses a binary-target plugin like
  `LintablePlugins`.

Phase 6 ships a template for this package, both plugin variants and the guide.

## Extension points kept open

- **Module rules.** Some future rules need facts from many files (who calls a
  function in another file). The engine is built so a `ModuleRule` can be added
  without changing `Rule`: a per-file `collect` step that runs in parallel and
  returns `Sendable` facts, then an `analyze` step over all of a module's facts.
  The plugin already knows each target's files; the CLI would group files by a
  `modules:` config section. Not in 0.x.
- **Fix-its.** `Violation` can gain text edits and a `lintable fix` command.
  Adding a stored property with a default doesn't break rules.

## Versioning

- Semantic versioning. During 0.x, a minor release may change the rule API; the
  changelog says how to update.
- A rule's ID never changes once released. A rule that behaves differently
  enough to surprise adopters gets a new option, not a silent change.
- Adding a built-in rule is never breaking, because rules are opt-in.

## Targets for performance

Not measured yet, to be checked in phase 4 on Habitify (about 1,000 Swift files):
a cold run under 5 seconds and a fully cached run under 1 second on an Apple
silicon Mac.

## Not in scope

- Style, formatting and naming rules.
- Type-checked analysis (SourceKit, the compiler's index). Rules stay syntactic,
  fast and predictable.
- Loading rules at run time from dynamic libraries.
- Windows.
