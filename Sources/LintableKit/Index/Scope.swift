import SwiftSyntax

public struct Scope: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case function
        case initializer
        case deinitializer
        case subscriptDeclaration
        case accessor(String)
        case closure
        case propertyInitializer
        case topLevel
    }

    public let kind: Kind
    public let node: Syntax
    public let name: String
    public let signature: FunctionSignature?

    public var isClosure: Bool {
        kind == .closure
    }

    public var isLocalFunction: Bool {
        guard kind == .function else { return false }
        var current = node.parent
        while let ancestor = current {
            if ancestor.is(MemberBlockSyntax.self) || ancestor.is(SourceFileSyntax.self) {
                return false
            }
            if ancestor.is(CodeBlockSyntax.self) || ancestor.is(ClosureExprSyntax.self) {
                return true
            }
            current = ancestor.parent
        }
        return false
    }

    static func make(_ node: Syntax, child: Syntax) -> Scope? {
        if let decl = node.as(FunctionDeclSyntax.self) {
            let signature = FunctionSignature(decl)
            return Scope(kind: .function, node: node, name: "`\(signature.displayName)`", signature: signature)
        }
        if let decl = node.as(InitializerDeclSyntax.self) {
            let signature = FunctionSignature(decl)
            return Scope(kind: .initializer, node: node, name: "`\(signature.displayName)`", signature: signature)
        }
        if node.is(DeinitializerDeclSyntax.self) {
            return Scope(kind: .deinitializer, node: node, name: "`deinit`", signature: nil)
        }
        if node.is(SubscriptDeclSyntax.self) {
            return Scope(kind: .subscriptDeclaration, node: node, name: "a subscript", signature: nil)
        }
        if let decl = node.as(AccessorDeclSyntax.self) {
            let specifier = decl.accessorSpecifier.text
            return Scope(kind: .accessor(specifier), node: node, name: accessorName(specifier, of: node), signature: nil)
        }
        if let block = node.as(AccessorBlockSyntax.self), case .getter = block.accessors {
            return Scope(kind: .accessor("get"), node: node, name: accessorName("get", of: node), signature: nil)
        }
        if node.is(ClosureExprSyntax.self) {
            return Scope(kind: .closure, node: node, name: "a closure", signature: nil)
        }
        if let binding = node.as(PatternBindingSyntax.self),
           binding.initializer?.id == child.id,
           binding.parent?.parent?.as(VariableDeclSyntax.self)?.parent?.is(MemberBlockItemSyntax.self) == true
        {
            return Scope(kind: .propertyInitializer, node: node, name: "the initial value of `\(binding.pattern.trimmedDescription)`", signature: nil)
        }
        return nil
    }

    private static func accessorName(_ specifier: String, of node: Syntax) -> String {
        var current = node.parent
        while let ancestor = current {
            if let binding = ancestor.as(PatternBindingSyntax.self) {
                return "the `\(specifier)` of `\(binding.pattern.trimmedDescription)`"
            }
            if ancestor.is(SubscriptDeclSyntax.self) {
                return "the `\(specifier)` of a subscript"
            }
            current = ancestor.parent
        }
        return "the `\(specifier)` accessor"
    }
}
