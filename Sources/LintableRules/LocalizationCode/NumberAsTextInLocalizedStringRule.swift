import LintableKit
import SwiftSyntax

public struct NumberAsTextInLocalizedStringRule: Rule {
    public init(options _: NoOptions) {}

    public func check(_ file: LintFile) -> [Violation] {
        let visitor = NumberAsTextVisitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.violations
    }
}

private final class NumberAsTextVisitor: SyntaxVisitor {
    var violations: [Violation] = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let key = LocalizationSyntax.localizedKeyLiteral(of: node) else { return .visitChildren }
        for expression in LocalizationSyntax.interpolations(of: key) {
            guard let conversion = textConversion(expression) else { continue }
            let message = "`\(conversion)` turns the value into text, so the String Catalog gets `%@` and can't pick a "
                + "plural form for it. Interpolate the number itself."
            violations.append(Violation(at: expression, message: message))
        }
        return .visitChildren
    }

    private static let countWords = [
        "count", "number", "total", "amount", "quantity", "streak", "days", "weeks", "months", "years", "hours",
        "minutes", "seconds", "times", "steps", "length", "index", "remaining", "completed", "goal", "percent",
    ]

    private func textConversion(_ expression: ExprSyntax) -> String? {
        if let call = expression.as(FunctionCallExprSyntax.self), LocalizationSyntax.calleeName(call) == "String",
           call.arguments.count == 1, let argument = call.arguments.first,
           argument.label == nil || argument.label?.text == "describing", looksLikeCount(argument.expression)
        {
            return call.trimmedDescription
        }
        if let member = expression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "description",
           let base = member.base, looksLikeCount(base)
        {
            return member.trimmedDescription
        }
        return nil
    }

    private func looksLikeCount(_ expression: ExprSyntax) -> Bool {
        if expression.is(IntegerLiteralExprSyntax.self) || expression.is(FloatLiteralExprSyntax.self) {
            return true
        }
        let name: String
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            name = reference.baseName.text
        } else if let member = expression.as(MemberAccessExprSyntax.self) {
            name = member.declName.baseName.text
        } else {
            return false
        }
        let lowercased = name.lowercased()
        return Self.countWords.contains { lowercased.contains($0) }
    }
}

public extension NumberAsTextInLocalizedStringRule {
    static let description = RuleDescription(
        id: "number_as_text_in_localized_string",
        name: "Number as text in a localized string",
        summary: "A localized string interpolates a number already turned into text.",
        rationale: """
        `String(localized: "\\(count) habits")` reaches the String Catalog as `%lld habits`, which can vary by \
        plural. `"\\(String(count)) habits"` or `"\\(count.description) habits"` reaches it as `%@ habits`, which can't, \
        so every language shows one form for every number. The rule reports `String(…)`, `String(describing:)` and \
        `.description` of a value named like a count, such as `count`, `total` or `streakLength`, interpolated into \
        `String(localized:)`, `Text("…")`, `LocalizedStringKey`, `LocalizedStringResource` and \
        `AttributedString(localized:)`.
        """,
        category: .localization,
        defaultSeverity: .warning,
        triggeringExamples: [
            Example("""
            let title = String(localized: "\\(1️⃣String(count)) habits", comment: "Number of habits.")
            """),
            Example("""
            Text("\\(2️⃣streak.description) day streak")
            """),
        ],
        nonTriggeringExamples: [
            Example("""
            let title = String(localized: "\\(count) habits", comment: "Number of habits.")
            let summary = "\\(String(count))/\\(total)"
            let name = String(localized: "\\(String(title.characters)) note", comment: "A note's title.")
            """),
        ],
        howToFix: "Interpolate the number itself: `String(localized: \"\\(count) habits\", comment: \"…\")`."
    )
}
