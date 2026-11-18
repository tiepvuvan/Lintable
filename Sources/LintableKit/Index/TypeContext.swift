import SwiftSyntax

public struct TypeContext: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case `class`
        case `struct`
        case `enum`
        case `actor`
        case `protocol`
        case `extension`
    }

    public let kind: Kind
    public let name: String
    public let inheritedTypes: [String]
    public let accessLevel: AccessLevel?
    public let node: Syntax

    init?(_ node: Syntax) {
        let kind: Kind
        let name: String
        let inheritance: InheritanceClauseSyntax?
        if let decl = node.as(ClassDeclSyntax.self) {
            (kind, name, inheritance) = (.class, decl.name.text, decl.inheritanceClause)
        } else if let decl = node.as(StructDeclSyntax.self) {
            (kind, name, inheritance) = (.struct, decl.name.text, decl.inheritanceClause)
        } else if let decl = node.as(EnumDeclSyntax.self) {
            (kind, name, inheritance) = (.enum, decl.name.text, decl.inheritanceClause)
        } else if let decl = node.as(ActorDeclSyntax.self) {
            (kind, name, inheritance) = (.actor, decl.name.text, decl.inheritanceClause)
        } else if let decl = node.as(ProtocolDeclSyntax.self) {
            (kind, name, inheritance) = (.protocol, decl.name.text, decl.inheritanceClause)
        } else if let decl = node.as(ExtensionDeclSyntax.self) {
            (kind, name, inheritance) = (.extension, Self.simpleName(of: decl.extendedType), decl.inheritanceClause)
        } else {
            return nil
        }
        self.kind = kind
        self.name = name
        inheritedTypes = inheritance?.inheritedTypes.map { Self.simpleName(of: $0.type) } ?? []
        accessLevel = Self.modifiers(of: node).flatMap(AccessLevel.explicit(in:))
        self.node = node
    }

    public var isValueType: Bool {
        kind == .struct || kind == .enum
    }

    static func modifiers(of node: Syntax) -> DeclModifierListSyntax? {
        if let decl = node.as(ClassDeclSyntax.self) { return decl.modifiers }
        if let decl = node.as(StructDeclSyntax.self) { return decl.modifiers }
        if let decl = node.as(EnumDeclSyntax.self) { return decl.modifiers }
        if let decl = node.as(ActorDeclSyntax.self) { return decl.modifiers }
        if let decl = node.as(ProtocolDeclSyntax.self) { return decl.modifiers }
        if let decl = node.as(ExtensionDeclSyntax.self) { return decl.modifiers }
        return nil
    }

    static func simpleName(of type: TypeSyntax) -> String {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return simpleName(of: attributed.baseType)
        }
        return type.trimmedDescription
    }
}
