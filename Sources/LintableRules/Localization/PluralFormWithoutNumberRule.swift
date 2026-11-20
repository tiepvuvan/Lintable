import LintableKit

public struct PluralFormWithoutNumberRule: CatalogRule {
    public init(options _: NoOptions) {}

    public func check(_ catalog: StringCatalog) -> [Violation] {
        var violations: [Violation] = []
        for entry in catalog.entries where entry.needsTranslation {
            for localization in entry.localizations {
                guard let rules = PluralRules(language: localization.language) else { continue }
                for group in localization.content.pluralGroups {
                    violations += check(group, of: entry, in: localization.language, rules: rules)
                }
            }
        }
        return violations
    }

    private func check(_ group: StringCatalog.PluralGroup, of entry: StringCatalog.Entry, in language: String, rules: PluralRules) -> [Violation] {
        group.cases.compactMap { variationCase in
            guard let category = PluralCategory(rawValue: variationCase.name) else { return nil }
            let numbers = rules.numbers(in: category, explicitZero: group.hasExplicitZero)
            guard numbers.count > 1, !variationCase.content.showsNumber else { return nil }
            let message = "The \(language) “\(category.rawValue)” form of \(CatalogText.quoted(entry.key)) is used for "
                + "\(CatalogText.numbers(numbers)), but \(CatalogText.quoted(variationCase.content.text)) doesn't show the number."
            return Violation(position: variationCase.position, message: message)
        }
    }
}

public extension PluralFormWithoutNumberRule {
    static let description = RuleDescription(
        id: "plural_form_without_number",
        name: "Plural form without a number",
        summary: "A plural form is used for several numbers but doesn't show the number.",
        rationale: """
        In many languages one plural form covers several numbers. Russian, Ukrainian, Croatian and Serbian use \
        `one` for 1, 21, 31 and 101; French, Portuguese and Hindi use it for 0 and 1. A form written without the \
        number, such as «Каждый день» (every day) for “Every %lld days”, then reads the same for 21 as for 1. The \
        rule reports forms that cover more than one whole number up to 200 and contain no number placeholder. \
        Foundation uses a `zero` form for 0 in every language, so a `zero` form takes 0 away from the others.
        """,
        category: .localization,
        defaultSeverity: .error,
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                "Every %lld days" : {
                  "localizations" : {
                    "ru" : {
                      "variations" : {
                        "plural" : {
                          "few" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дня" } },
                          "many" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дней" } },
                          1️⃣"one" : { "stringUnit" : { "state" : "translated", "value" : "Каждый день" } },
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дня" } }
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
        nonTriggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                "Every %lld days" : {
                  "localizations" : {
                    "en" : {
                      "variations" : {
                        "plural" : {
                          "one" : { "stringUnit" : { "state" : "translated", "value" : "Every day" } },
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "Every %lld days" } }
                        }
                      }
                    },
                    "fr" : {
                      "variations" : {
                        "plural" : {
                          "one" : { "stringUnit" : { "state" : "translated", "value" : "Tous les jours" } },
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } },
                          "zero" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } }
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
        Put the number in the form, for example «Каждый %lld день». Where the form only adds 0 to 1, as in French, \
        add a `zero` form instead.
        """,
        fileKind: .stringCatalog
    )
}
