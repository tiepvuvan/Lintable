import LintableKit

public struct StaleStringRule: CatalogRule {
    public init(options _: NoOptions) {}

    public func check(_ catalog: StringCatalog) -> [Violation] {
        catalog.entries.filter(\.isStale).map { entry in
            Violation(position: entry.position, message: "\(CatalogText.quoted(entry.key)) is stale: the code no longer uses it.")
        }
    }
}

public extension StaleStringRule {
    static let description = RuleDescription(
        id: "stale_string",
        name: "Stale string",
        summary: "A String Catalog keeps a string the code no longer uses.",
        rationale: """
        Xcode marks a key stale when the code stops using it, and keeps it with its translations in case it comes \
        back. Stale keys make translators work on text nobody sees and make catalogs harder to review.
        """,
        category: .localization,
        defaultSeverity: .warning,
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                1️⃣"Old onboarding title" : {
                  "extractionState" : "stale",
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Alter Titel" } }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        nonTriggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                "Welcome" : {
                  "extractionState" : "manual",
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Willkommen" } }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        howToFix: """
        Delete the string from the catalog. If the code builds the key at run time, which Xcode can't see, set its \
        extraction state to `manual` instead.
        """,
        fileKind: .stringCatalog
    )
}
