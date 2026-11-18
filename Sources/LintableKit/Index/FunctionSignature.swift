import SwiftSyntax

public struct FunctionSignature: Sendable, Hashable {
    public struct Parameter: Sendable, Hashable {
        public let label: String?
        public let hasDefaultValue: Bool
        public let isVariadic: Bool
    }

    public let baseName: String
    public let parameters: [Parameter]
    public let isOverride: Bool
    public let isStatic: Bool
    public let accessLevel: AccessLevel
    public let attributes: [String]
    public let node: Syntax

    public var labels: [String?] {
        parameters.map(\.label)
    }

    public var displayName: String {
        "\(baseName)(\(parameters.map { "\($0.label ?? "_"):" }.joined()))"
    }

    public var isObjC: Bool {
        attributes.contains("objc") || attributes.contains("IBAction") || attributes.contains("IBSegueAction")
    }

    public func hasAttribute(_ name: String) -> Bool {
        attributes.contains(name)
    }

    init(_ decl: FunctionDeclSyntax) {
        self.init(
            baseName: decl.name.text,
            parameterClause: decl.signature.parameterClause,
            modifiers: decl.modifiers,
            attributes: decl.attributes,
            node: Syntax(decl)
        )
    }

    init(_ decl: InitializerDeclSyntax) {
        self.init(
            baseName: "init",
            parameterClause: decl.signature.parameterClause,
            modifiers: decl.modifiers,
            attributes: decl.attributes,
            node: Syntax(decl)
        )
    }

    private init(
        baseName: String,
        parameterClause: FunctionParameterClauseSyntax,
        modifiers: DeclModifierListSyntax,
        attributes: AttributeListSyntax,
        node: Syntax
    ) {
        self.baseName = baseName
        parameters = parameterClause.parameters.map { parameter in
            Parameter(
                label: parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.text,
                hasDefaultValue: parameter.defaultValue != nil,
                isVariadic: parameter.ellipsis != nil
            )
        }
        let modifierNames = modifiers.map(\.name.text)
        isOverride = modifierNames.contains("override")
        isStatic = modifierNames.contains("static") || modifierNames.contains("class")
        accessLevel = Self.effectiveAccessLevel(declared: AccessLevel.explicit(in: modifiers), node: node)
        self.attributes = attributes.compactMap { element in
            element.as(AttributeSyntax.self)?.attributeName.trimmedDescription
        }
        self.node = node
    }

    private static func effectiveAccessLevel(declared: AccessLevel?, node: Syntax) -> AccessLevel {
        var level = declared
        var isInsideFilePrivateType = false
        var current = node.parent
        while let ancestor = current {
            if let modifiers = TypeContext.modifiers(of: ancestor) {
                let explicit = AccessLevel.explicit(in: modifiers)
                if level == nil, ancestor.is(ExtensionDeclSyntax.self), let explicit {
                    level = explicit == .private ? .fileprivate : explicit
                }
                if let explicit, explicit <= .fileprivate {
                    isInsideFilePrivateType = true
                }
            }
            current = ancestor.parent
        }
        let resolved = level ?? .internal
        return isInsideFilePrivateType ? min(resolved, .fileprivate) : resolved
    }
}
