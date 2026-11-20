import LintableKit

public struct NumberWithoutPluralRule: CatalogRule {
    public struct Options: RuleOptions {
        public var ignoredKeys: [String] = []
        public var ignoredWords: [String] = []

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ catalog: StringCatalog) -> [Violation] {
        guard catalog.sourceLanguage.lowercased().hasPrefix("en") else { return [] }
        let ignoredKeys = Set(options.ignoredKeys)
        let ignoredWords = Set(options.ignoredWords.map { $0.lowercased() })
        return catalog.entries.compactMap { entry in
            guard entry.needsTranslation, !ignoredKeys.contains(entry.key) else { return nil }
            let content = catalog.sourceContent(of: entry)
            guard content.pluralGroups.isEmpty,
                  let phrase = EnglishCount.phraseForOne(in: content.text, ignoring: ignoredWords)
            else {
                return nil
            }
            let message = "\(CatalogText.quoted(entry.key)) reads “\(phrase)” when the number is 1. Vary it by plural."
            return Violation(position: entry.position, message: message)
        }
    }
}

public extension NumberWithoutPluralRule {
    static let description = RuleDescription(
        id: "number_without_plural",
        name: "Number without plural",
        summary: "An English source string counts something without varying by plural.",
        rationale: """
        “%lld records” reads “1 records” when the number is 1, and translators rarely add plural forms the source \
        doesn't have. The rule looks at String Catalogs whose source language is English. It reports a string with no \
        plural variation where an integer placeholder is followed by a word that looks plural, directly or after one \
        other word. Numbers inside `^[…](inflect: true)` are left to Foundation's automatic grammar agreement.
        """,
        category: .localization,
        defaultSeverity: .warning,
        optionDescriptions: [
            "ignored_keys": "Keys to skip, such as one that only ever shows numbers above 1.",
            "ignored_words": "Words ending in s after a number that aren't plurals in your strings.",
        ],
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                1️⃣"%lld records" : {
                },
                2️⃣"%1$lld of %2$lld days complete" : {
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
                "%lld this week" : {
                },
                "Step %1$lld of %2$lld" : {
                },
                "Best: ^[%lld days](inflect: true)" : {
                },
                "%lld habits" : {
                  "localizations" : {
                    "en" : {
                      "variations" : {
                        "plural" : {
                          "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld habit" } },
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld habits" } }
                        }
                      }
                    }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        howToFix: """
        Vary the string by plural in Xcode's String Catalog editor (one: “%lld record”, other: “%lld records”), \
        or rephrase it so the number doesn't count a noun, such as “Records: %lld”.
        """,
        fileKind: .stringCatalog
    )
}
