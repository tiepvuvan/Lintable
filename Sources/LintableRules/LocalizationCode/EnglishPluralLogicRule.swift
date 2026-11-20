import LintableKit
import SwiftSyntax

public struct EnglishPluralLogicRule: Rule {
    public init(options _: NoOptions) {}

    public func check(_ file: LintFile) -> [Violation] {
        let visitor = EnglishPluralLogicVisitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.violations
    }
}

private final class EnglishPluralLogicVisitor: SyntaxVisitor {
    private static let comparisons: Set<String> = ["==", "!=", ">", "<", ">=", "<="]

    var violations: [Violation] = []

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        guard comparesWithOne(node.condition),
              let first = node.thenExpression.as(StringLiteralExprSyntax.self),
              let second = node.elseExpression.as(StringLiteralExprSyntax.self)
        else {
            return .visitChildren
        }
        let choices = [first, second].map { "“\(LocalizationSyntax.text(of: $0))”" }.joined(separator: " or ")
        let message = "Choosing \(choices) by comparing a count with 1 only works in English. "
            + "Vary a localized string by plural instead."
        violations.append(Violation(at: node, message: message))
        return .visitChildren
    }

    private func comparesWithOne(_ condition: ExprSyntax) -> Bool {
        guard let comparison = condition.as(InfixOperatorExprSyntax.self),
              let operatorToken = comparison.operator.as(BinaryOperatorExprSyntax.self),
              Self.comparisons.contains(operatorToken.operator.text)
        else {
            return false
        }
        let limits: Set<String> = ["1", "2"]
        return [comparison.leftOperand, comparison.rightOperand].contains { operand in
            operand.as(IntegerLiteralExprSyntax.self).map { limits.contains($0.literal.text) } ?? false
        }
    }
}

public extension EnglishPluralLogicRule {
    static let description = RuleDescription(
        id: "english_plural_logic",
        name: "English plural logic",
        summary: "Code picks a singular or plural word by comparing a count with 1.",
        rationale: """
        `count == 1 ? "day" : "days"` and `"day\\(count == 1 ? "" : "s")"` hard-code English grammar. Russian needs \
        a different word for 1, 2–4 and 5–20, Arabic six forms, and Japanese none, and translators never see these \
        words. The rule reports a ternary that compares with 1 or 2 and chooses between two string literals.
        """,
        category: .localization,
        defaultSeverity: .warning,
        triggeringExamples: [
            Example("""
            func label(for count: Int) -> String {
                "\\(count) day\\(1️⃣count == 1 ? "" : "s")"
            }
            """),
            Example("""
            let unit = 1️⃣habits.count > 1 ? "habits" : "habit"
            """),
        ],
        nonTriggeringExamples: [
            Example("""
            func label(for count: Int) -> String {
                String(localized: "\\(count) days", comment: "A number of days; varies by plural in the String Catalog.")
            }
            """),
            Example("""
            let icon = count == 1 ? Icon.single : Icon.many
            """),
        ],
        howToFix: """
        Use one localized string with the number, `String(localized: "\\(count) days", comment: "…")`, and vary it by \
        plural in the String Catalog.
        """
    )
}
