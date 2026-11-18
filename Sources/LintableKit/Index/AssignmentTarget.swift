import SwiftSyntax

public struct AssignmentTarget: Sendable, Hashable {
    public enum Root: Sendable, Hashable {
        case explicitSelf
        case name(String)
        case other
    }

    public static let operators: Set<String> = ["=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="]

    public let root: Root
    public let members: [String]
    public let operatorText: String
    public let node: Syntax

    public var path: [String] {
        if case let .name(name) = root {
            return [name] + members
        }
        return members
    }

    static func make(left: ExprSyntax, operatorText: String) -> AssignmentTarget? {
        var members: [String] = []
        var current = left
        while true {
            if let member = current.as(MemberAccessExprSyntax.self) {
                members.insert(member.declName.baseName.text, at: 0)
                guard let base = member.base else {
                    return AssignmentTarget(root: .other, members: members, operatorText: operatorText, node: Syntax(left))
                }
                current = base
            } else if let optional = current.as(OptionalChainingExprSyntax.self) {
                current = optional.expression
            } else if let forced = current.as(ForceUnwrapExprSyntax.self) {
                current = forced.expression
            } else if let reference = current.as(DeclReferenceExprSyntax.self) {
                let root: Root = reference.baseName.text == "self" ? .explicitSelf : .name(reference.baseName.text)
                return AssignmentTarget(root: root, members: members, operatorText: operatorText, node: Syntax(left))
            } else if current.is(SuperExprSyntax.self) {
                return AssignmentTarget(root: .explicitSelf, members: members, operatorText: operatorText, node: Syntax(left))
            } else if current.is(TupleExprSyntax.self), members.isEmpty {
                return nil
            } else {
                return AssignmentTarget(root: .other, members: members, operatorText: operatorText, node: Syntax(left))
            }
        }
    }
}
