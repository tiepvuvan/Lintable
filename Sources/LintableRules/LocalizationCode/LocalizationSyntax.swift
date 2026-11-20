import LintableKit
import SwiftSyntax

enum LocalizationSyntax {
    static func calleeName(_ call: FunctionCallExprSyntax) -> String? {
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            if member.declName.baseName.text == "init", let base = member.base?.as(DeclReferenceExprSyntax.self) {
                return base.baseName.text
            }
            return member.declName.baseName.text
        }
        return nil
    }

    static func isLocalizationCall(_ call: FunctionCallExprSyntax) -> Bool {
        guard let name = calleeName(call) else { return false }
        switch name {
        case "NSLocalizedString", "LocalizedStringResource", "LocalizedStringKey":
            return true
        case "String", "AttributedString":
            return call.arguments.first?.label?.text == "localized"
        case "Text":
            guard let first = call.arguments.first, first.label == nil else { return false }
            return first.expression.is(StringLiteralExprSyntax.self)
        default:
            return false
        }
    }

    static func localizedKeyLiteral(of call: FunctionCallExprSyntax) -> StringLiteralExprSyntax? {
        guard isLocalizationCall(call) else { return nil }
        return call.arguments.first?.expression.as(StringLiteralExprSyntax.self)
    }

    static func isLocalizationCall(_ expression: ExprSyntax) -> Bool {
        expression.as(FunctionCallExprSyntax.self).map(isLocalizationCall) ?? false
    }

    static func text(of literal: StringLiteralExprSyntax) -> String {
        literal.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
    }

    static func interpolations(of literal: StringLiteralExprSyntax) -> [ExprSyntax] {
        literal.segments.compactMap { $0.as(ExpressionSegmentSyntax.self)?.expressions.first?.expression }
    }

    static func looksLikeUIText(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { $0.properties.isAlphabetic }
        guard let first = letters.first else { return false }
        let hasSpaceBetweenWords = text.trimmingCharacters(in: .whitespaces).contains(" ")
        let hasNonASCIILetter = letters.contains { !$0.isASCII }
        return hasSpaceBetweenWords || first.properties.isUppercase || hasNonASCIILetter
    }

    static func isInDebugOrPreviewCode(_ node: some SyntaxProtocol, index: SyntaxIndex) -> Bool {
        if index.types(of: node).contains(where: { $0.inheritedTypes.contains("PreviewProvider") }) {
            return true
        }
        var current = Syntax(node).parent
        while let ancestor = current {
            if let clause = ancestor.as(IfConfigClauseSyntax.self), let condition = clause.condition?.trimmedDescription {
                if condition == "DEBUG" || condition.hasPrefix("DEBUG ") || condition.hasSuffix(" DEBUG") {
                    return true
                }
            }
            if let macro = ancestor.as(MacroExpansionExprSyntax.self), macro.macroName.text == "Preview" {
                return true
            }
            if let macro = ancestor.as(MacroExpansionDeclSyntax.self), macro.macroName.text == "Preview" {
                return true
            }
            current = ancestor.parent
        }
        return false
    }

    static func quoted(_ text: String) -> String {
        let flattened = text.replacingOccurrences(of: "\n", with: " ")
        guard flattened.count > 50 else { return "“\(flattened)”" }
        return "“\(flattened.prefix(47))…”"
    }
}
