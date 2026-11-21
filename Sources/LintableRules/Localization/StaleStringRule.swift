import LintableKit

public struct StaleStringRule: CatalogRule {
    public struct Options: RuleOptions {
        public var ignoredKeys: [String] = []

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ catalog: StringCatalog) -> [Violation] {
        let ignoredKeys = Set(options.ignoredKeys)
        return catalog.entries.filter { $0.isStale && !ignoredKeys.contains($0.key) }.map { entry in
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
        optionDescriptions: [
            "ignored_keys": "Keys kept stale on purpose, such as the strings of code that the build excludes for now.",
        ],
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
        Delete the string from the catalog. If the code builds the key at run time, or a package looks it up in this \
        target's bundle, which Xcode can't see, set its extraction state to `manual` instead. Keep a string of code \
        that the build excludes for now by listing it in `ignored_keys`.
        """,
        fileKind: .stringCatalog
    )
}
