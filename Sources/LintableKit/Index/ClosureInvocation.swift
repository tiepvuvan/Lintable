import SwiftSyntax

public struct ClosureInvocation: Sendable, Hashable {
    public let calleeComponents: [String]
    public let call: Syntax

    public var calleeName: String {
        calleeComponents.joined(separator: ".")
    }

    public func matches(_ pattern: String) -> Bool {
        let parts = pattern.split(separator: ".").map(String.init)
        guard let last = parts.last, calleeComponents.last == last else { return false }
        guard parts.count > 1 else { return true }
        guard calleeComponents.first == parts.first, calleeComponents.count >= parts.count else { return false }
        var middle = calleeComponents.dropFirst().dropLast()[...]
        for part in parts.dropFirst().dropLast() {
            guard let found = middle.firstIndex(of: part) else { return false }
            middle = middle[middle.index(after: found)...]
        }
        return true
    }

    static func components(of expression: ExprSyntax) -> [String] {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return [reference.baseName.text]
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            return (member.base.map { components(of: $0) } ?? []) + [member.declName.baseName.text]
        }
        if let call = expression.as(FunctionCallExprSyntax.self) {
            return components(of: call.calledExpression)
        }
        if let optional = expression.as(OptionalChainingExprSyntax.self) {
            return components(of: optional.expression)
        }
        if let forced = expression.as(ForceUnwrapExprSyntax.self) {
            return components(of: forced.expression)
        }
        if let specialized = expression.as(GenericSpecializationExprSyntax.self) {
            return components(of: specialized.expression)
        }
        return [expression.trimmedDescription]
    }
}
