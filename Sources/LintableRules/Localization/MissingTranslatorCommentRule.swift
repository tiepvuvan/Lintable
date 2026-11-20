import LintableKit

public struct MissingTranslatorCommentRule: CatalogRule {
    public init(options _: NoOptions) {}

    public func check(_ catalog: StringCatalog) -> [Violation] {
        catalog.entries.filter { $0.needsTranslation && ($0.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { entry in
            Violation(position: entry.position, message: "\(CatalogText.quoted(entry.key)) has no comment for translators.")
        }
    }
}

public extension MissingTranslatorCommentRule {
    static let description = RuleDescription(
        id: "missing_translator_comment",
        name: "Missing translator comment",
        summary: "A String Catalog key has no comment for translators.",
        rationale: """
        Translators see a key without the screen around it. "Done" can be a button or a status, "Log" a verb or a \
        noun, and a comment is the only place that says which. The rule reports keys with no comment, skipping keys \
        marked Don't Translate, stale keys and empty keys.
        """,
        category: .localization,
        defaultSeverity: .warning,
        triggeringExamples: [
            Example("""
            {
              "sourceLanguage" : "en",
              "strings" : {
                1️⃣"Done" : {
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
                  "comment" : "Button that closes the reminder editor."
                },
                "Habitify" : {
                  "shouldTranslate" : false
                }
              },
              "version" : "1.0"
            }
            """),
        ],
        howToFix: "Pass `comment:` where the code creates the string, or add the comment in Xcode's String Catalog editor.",
        fileKind: .stringCatalog
    )
}
