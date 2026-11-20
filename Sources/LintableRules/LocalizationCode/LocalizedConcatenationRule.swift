import LintableKit
import SwiftSyntax

public struct LocalizedConcatenationRule: Rule {
    public init(options _: NoOptions) {}

    public func check(_ file: LintFile) -> [Violation] {
        let visitor = LocalizedConcatenationVisitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.violations
    }
}

private final class LocalizedConcatenationVisitor: SyntaxVisitor {
    private static let message = "This builds text out of localized pieces, which keeps English word order and "
        + "punctuation in every language. Localize the whole text as one string with placeholders."

    var violations: [Violation] = []

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard isPlus(node), !isPlus(node.parent) else { return .visitChildren }
        let operands = flattenedOperands(of: node)
        let localized = operands.filter(LocalizationSyntax.isLocalizationCall)
        let textual = operands.filter { $0.is(StringLiteralExprSyntax.self) || LocalizationSyntax.isLocalizationCall($0) }
        if !localized.isEmpty, textual.count >= 2 {
            violations.append(Violation(at: node, message: Self.message))
        }
        return .visitChildren
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        guard !isLocalizedKey(node) else { return .visitChildren }
        let interpolations = LocalizationSyntax.interpolations(of: node)
        let localizedCount = interpolations.filter(LocalizationSyntax.isLocalizationCall).count
        guard localizedCount > 0 else { return .visitChildren }
        let hasOtherText = !LocalizationSyntax.text(of: node).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasOtherText || interpolations.count > 1 {
            violations.append(Violation(at: node, message: Self.message))
        }
        return .visitChildren
    }

    private func isPlus(_ node: Syntax?) -> Bool {
        guard let infix = node?.as(InfixOperatorExprSyntax.self) else { return false }
        return isPlus(infix)
    }

    private func isPlus(_ node: InfixOperatorExprSyntax) -> Bool {
        node.operator.as(BinaryOperatorExprSyntax.self)?.operator.text == "+"
    }

    private func flattenedOperands(of node: InfixOperatorExprSyntax) -> [ExprSyntax] {
        [node.leftOperand, node.rightOperand].flatMap { operand -> [ExprSyntax] in
            if let nested = operand.as(InfixOperatorExprSyntax.self), isPlus(nested) {
                return flattenedOperands(of: nested)
            }
            return [operand]
        }
    }

    private func isLocalizedKey(_ literal: StringLiteralExprSyntax) -> Bool {
        guard let call = literal.parent?.parent?.parent?.as(FunctionCallExprSyntax.self) else { return false }
        return LocalizationSyntax.localizedKeyLiteral(of: call)?.id == literal.id
    }
}

public extension LocalizedConcatenationRule {
    static let description = RuleDescription(
        id: "localized_concatenation",
        name: "Localized concatenation",
        summary: "Text built by joining localized pieces.",
        rationale: """
        `String(localized: "Completed") + " " + String(localized: "today")` and \
        `"\\(String(localized: "times")), \\(String(localized: "mins"))"` keep English word order, spacing and \
        punctuation in every language, and translators see the pieces without the sentence. The rule reports `+` \
        between a localized string and other text, and a plain string literal that interpolates a localized string \
        next to other text or values.
        """,
        category: .localization,
        defaultSeverity: .warning,
        triggeringExamples: [
            Example("""
            let summary = 1️⃣String(localized: "Completed", comment: "Status.") + " " + String(localized: "today", comment: "Day.")
            """),
            Example("""
            let units = 1️⃣"\\(String(localized: "times", comment: "Unit.")), \\(String(localized: "mins", comment: "Unit."))…"
            """),
        ],
        nonTriggeringExamples: [
            Example("""
            let summary = String(localized: "Completed today", comment: "Status.")
            let line = String(localized: "\\(name) completed today", comment: "Status of a habit.")
            let path = "\\(folder)/\\(file)"
            """),
        ],
        howToFix: """
        Localize the whole text as one string, with placeholders for the values: \
        `String(localized: "\\(name) completed today", comment: "…")`.
        """
    )
}
