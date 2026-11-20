import LintableKit

public struct MissingPluralFormRule: CatalogRule {
    public init(options _: NoOptions) {}

    public func check(_ catalog: StringCatalog) -> [Violation] {
        var violations: [Violation] = []
        for entry in catalog.entries where entry.needsTranslation {
            for localization in entry.localizations {
                guard let rules = PluralRules(language: localization.language) else { continue }
                for group in localization.content.pluralGroups {
                    let missing = rules.requiredCategories.subtracting(group.categories).sorted()
                    guard !missing.isEmpty else { continue }
                    let forms = CatalogText.list(missing.map(\.rawValue), conjunction: "or")
                    let message = "The \(localization.language) plural of \(CatalogText.quoted(entry.key)) has no \(forms) form."
                    violations.append(Violation(position: group.position, message: message))
                }
            }
        }
        return violations
    }
}

public extension MissingPluralFormRule {
    static let description = RuleDescription(
        id: "missing_plural_form",
        name: "Missing plural form",
        summary: "A plural variation lacks a form its language needs.",
        rationale: """
        Languages need different plural forms: English uses one and other, Russian one, few, many and other, Arabic \
        all six. When a form is missing, Foundation falls back to `other`, so Russian reads «21 дней» instead of \
        «21 день». The rule checks every plural variation, the source language's too, against the CLDR plural rules \
        for whole numbers up to 1,000. Forms only used for millions, such as French `many`, aren't required. \
        Languages the rule doesn't know are skipped.
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
                        1️⃣"plural" : {
                          "one" : { "stringUnit" : { "state" : "translated", "value" : "Каждый %lld день" } },
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
                    "fr" : {
                      "variations" : {
                        "plural" : {
                          "one" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jour" } },
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } }
                        }
                      }
                    },
                    "ja" : {
                      "variations" : {
                        "plural" : {
                          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld日ごと" } }
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
        howToFix: "Add the missing forms in Xcode's String Catalog editor, which lists the forms each language needs.",
        fileKind: .stringCatalog
    )
}
