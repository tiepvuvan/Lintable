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
