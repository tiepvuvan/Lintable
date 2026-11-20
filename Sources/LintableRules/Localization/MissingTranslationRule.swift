import LintableKit

public struct MissingTranslationRule: CatalogRule {
    public struct Options: RuleOptions {
        public var languages: [String] = []
        public var acceptedStates = ["translated"]

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ catalog: StringCatalog) -> [Violation] {
        let languages = (options.languages.isEmpty ? catalog.targetLanguages : options.languages)
            .filter { $0 != catalog.sourceLanguage }
        let accepted = Set(options.acceptedStates)
        return catalog.entries.filter(\.needsTranslation).compactMap { entry in
            var missing: [String] = []
            var unfinished: [String: [String]] = [:]
            for language in languages {
                guard let units = entry.localization(for: language)?.content.units, !units.isEmpty else {
                    missing.append(language)
                    continue
                }
                if let state = Set(units.map { $0.state ?? "translated" }).subtracting(accepted).min() {
                    unfinished[state, default: []].append(language)
                }
            }
            return violation(for: entry, missing: missing, unfinished: unfinished)
        }
    }

    private func violation(for entry: StringCatalog.Entry, missing: [String], unfinished: [String: [String]]) -> Violation? {
        var problems: [String] = []
        if !missing.isEmpty {
            problems.append("isn't translated into \(CatalogText.list(missing))")
        }
        for state in unfinished.keys.sorted() {
            problems.append("is still `\(state)` in \(CatalogText.list(unfinished[state] ?? []))")
        }
        guard !problems.isEmpty else { return nil }
        return Violation(position: entry.position, message: "\(CatalogText.quoted(entry.key)) \(problems.joined(separator: "; it ")).")
    }
}

public extension MissingTranslationRule {
    static let description = RuleDescription(
        id: "missing_translation",
        name: "Missing translation",
        summary: "A string has no finished translation in one of the String Catalog's languages.",
        rationale: """
        A key without a translation shows its source text, usually English, to everyone who uses that language. \
        Xcode shows each catalog's completion but never fails a build over it, so new strings ship untranslated. \
        The rule reports each string that lacks a translation in a language the catalog has, or whose translation is \
        still marked `new` or `needs_review`. Keys Xcode marked stale, keys marked Don't Translate and empty keys are \
        skipped.

        To let Debug builds warn while release builds stop, keep the rule's severity at `warning`, give it \
        `release_severity: error` and set the config's `release_condition`, for example `!DEBUG`.
        """,
        category: .localization,
        defaultSeverity: .warning,
        optionDescriptions: [
            "languages": "The languages every string needs. Empty means every language the catalog has.",
            "accepted_states": "The translation states that count as finished.",
        ],
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                1️⃣"Done" : {
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Fertig" } }
                  }
                },
                "Save" : {
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Sichern" } },
                    "fr" : { "stringUnit" : { "state" : "translated", "value" : "Enregistrer" } }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                1️⃣"Done" : {
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "needs_review", "value" : "Fertig" } }
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
                "Done" : {
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Fertig" } },
                    "fr" : { "stringUnit" : { "state" : "translated", "value" : "Terminé" } }
                  }
                },
                "Habitify" : {
                  "shouldTranslate" : false
                },
                "Old text" : {
                  "extractionState" : "stale",
                  "localizations" : {
                    "de" : { "stringUnit" : { "state" : "translated", "value" : "Alter Text" } }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        howToFix: "Translate the string in Xcode's String Catalog editor, or mark it Don't Translate if it reads the same in every language.",
        fileKind: .stringCatalog
    )
}
