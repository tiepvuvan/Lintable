# ``LintableKit/CatalogRule``

A rule that checks a String Catalog (`.xcstrings`) instead of a Swift file.

## Overview

A catalog rule receives a parsed ``StringCatalog`` and returns violations at the
positions its entries, localizations and plural forms start, so Xcode shows them on
the right line of the JSON. List catalog rules in ``RulePack/catalogRules``.

```swift
struct NoTodoTranslationsRule: CatalogRule {
    static let description = RuleDescription(
        id: "no_todo_translations",
        name: "No TODO translations",
        summary: "A translation that still says TODO.",
        rationale: "Placeholder text ships when nobody notices it.",
        category: .localization,
        triggeringExamples: [Example("""
        { "sourceLanguage" : "en", "strings" : { "Done" : { "localizations" : {
          1️⃣"de" : { "stringUnit" : { "state" : "translated", "value" : "TODO" } } } } } }
        """)],
        fileKind: .stringCatalog
    )

    init(options: NoOptions) {}

    func check(_ catalog: StringCatalog) -> [Violation] {
        catalog.entries.flatMap { entry in
            catalog.translations(of: entry)
                .filter { $0.content.text.contains("TODO") }
                .map { Violation(position: $0.position, message: "The \($0.language) translation still says TODO.") }
        }
    }
}
```

Test catalog rules with `assertCatalogLint` and `verifyExamples(of:)` from
`LintableTesting`.

## Reading other catalogs

A rule that compares a catalog with others, such as a package's catalog whose
strings an app must also hold, names their paths in ``referencedCatalogPaths``
and implements ``check(_:in:)``. Lintable reads those catalogs once per run,
relative to the config file, and passes them in a ``CatalogContext``. A change to
a referenced catalog makes Lintable check the catalog again instead of using its
cached result. A path that can't be read or parsed is missing from the context.

```swift
var referencedCatalogPaths: [String] { [options.package] }

func check(_ catalog: StringCatalog) -> [Violation] {
    check(catalog, in: CatalogContext(relativePath: catalog.path))
}

func check(_ catalog: StringCatalog, in context: CatalogContext) -> [Violation] {
    guard let package = context.catalog(atPath: options.package) else { return [] }
    let keys = Set(catalog.entries.map(\.key))
    return package.entries.filter { !keys.contains($0.key) }.map {
        Violation(position: AbsolutePosition(utf8Offset: 0), message: "“\($0.key)” is missing.")
    }
}
```

Test such a rule with the `files` parameter of `assertCatalogLint`, and give its
examples ``Example/files``.
