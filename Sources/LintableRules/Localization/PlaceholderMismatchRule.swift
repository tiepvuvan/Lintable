import LintableKit

public struct PlaceholderMismatchRule: CatalogRule {
    public init(options _: NoOptions) {}

    public func check(_ catalog: StringCatalog) -> [Violation] {
        catalog.entries.filter(\.needsTranslation).flatMap { entry in
            let source = ArgumentSignature(catalog.sourceContent(of: entry))
            return catalog.translations(of: entry).compactMap { localization -> Violation? in
                let translation = ArgumentSignature(localization.content)
                guard translation != source else { return nil }
                let message = "The \(localization.language) translation of \(CatalogText.quoted(entry.key)) has "
                    + "\(translation.summary) where the source has \(source.summary)."
                return Violation(position: localization.position, message: message)
            }
        }
    }
}

public extension PlaceholderMismatchRule {
    static let description = RuleDescription(
        id: "placeholder_mismatch",
        name: "Placeholder mismatch",
        summary: "A translation's format specifiers don't match the source string's.",
        rationale: """
        Foundation fills a translation's specifiers with the arguments the code passes for the source string. A \
        translation that reads an integer as an object, `%@` where the source has `%lld`, crashes; one that drops or \
        adds an argument shows the wrong value. The rule compares the kind of argument each position reads in the \
        source and in every translation, using the `other` form of plural variations and the format specifier of \
        substitutions. Integer widths such as `%d`, `%ld` and `%lld` count as the same kind.
        """,
        category: .localization,
        defaultSeverity: .error,
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                "%lld habits" : {
                  "localizations" : {
                    1️⃣"de" : { "stringUnit" : { "state" : "translated", "value" : "%@ Gewohnheiten" } }
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
                "%1$@ has %2$lld habits" : {
                  "localizations" : {
                    "ja" : { "stringUnit" : { "state" : "translated", "value" : "%2$lld 個の習慣が %1$@ にあります" } }
                  }
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        howToFix: "Use the source's specifiers in the translation, with positions such as `%1$@` when the order changes.",
        fileKind: .stringCatalog
    )
}
