# ``LintableKit``

The rule API, and the syntax index that tells a rule where code is.

## Overview

A rule is a `Sendable` type that receives a parsed file and returns violations. The
``SyntaxIndex`` answers the questions that line-based linters can't: which function,
accessor or closure a node is in, the types around it and what they inherit from, who
calls a function in the file, and what a closure is passed to.

```swift
struct NoPrintInViewsRule: Rule {
    static let description = RuleDescription(
        id: "no_print_in_views",
        name: "No print in views",
        summary: "`print` inside a `UIView` subclass.",
        rationale: "Views shouldn't log; their owners should.",
        category: RuleCategory(id: "logging", name: "Logging"),
        triggeringExamples: [Example("final class A: UIView { func f() { 1️⃣print(1) } }")]
    )

    init(options: NoOptions) {}

    func check(_ file: LintFile) -> [Violation] {
        file.index.calls(named: "print")
            .filter { call in
                file.index.types(of: call.node).contains { file.index.inheritsFrom($0, anyOf: ["UIView"]) }
            }
            .map { Violation(at: $0.node, message: "Log from the view's owner, not the view.") }
    }
}
```

## Topics

### Writing rules

- <doc:WritingARule>
- ``Rule``
- ``RuleOptions``
- ``NoOptions``
- ``RuleDescription``
- ``RuleID``
- ``RuleCategory``
- ``Severity``
- ``Example``
- ``Violation``
- ``Note``
- ``RulePack``

### Reading a file

- ``LintFile``
- ``LineColumn``
- ``SyntaxIndex``
- ``Scope``
- ``FunctionSignature``
- ``AccessLevel``
- ``TypeContext``
- ``CallSite``
- ``Reference``
- ``ClosureInvocation``
- ``AssignmentTarget``
- ``LineMap``

### Checking String Catalogs

- ``CatalogRule``
- ``StringCatalog``
- ``StringCatalogError``
- ``PluralRules``
- ``PluralCategory``
- ``FormatSpecifier``
- ``FileKind``
- ``JSONDocument``
- ``JSONValue``
- ``JSONMember``
- ``JSONParseError``
