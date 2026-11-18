import SwiftSyntax

public extension SyntaxIndex {
    func isLocalVariable(named name: String, at node: some SyntaxProtocol) -> Bool {
        var child = Syntax(node)
        var current = child.parent
        while let ancestor = current {
            if ancestor.is(MemberBlockSyntax.self) {
                return false
            }
            if Self.declares(name, in: ancestor, before: child) {
                return true
            }
            child = ancestor
            current = ancestor.parent
        }
        return false
    }

    private static func declares(_ name: String, in ancestor: Syntax, before child: Syntax) -> Bool {
        if let list = ancestor.as(CodeBlockItemListSyntax.self) {
            for item in list {
                if item.id == child.id {
                    return false
                }
                if declares(name, item: item) {
                    return true
                }
            }
            return false
        }
        if let statement = ancestor.as(IfExprSyntax.self), statement.body.id == child.id {
            return binds(name, statement.conditions)
        }
        if let statement = ancestor.as(WhileStmtSyntax.self), statement.body.id == child.id {
            return binds(name, statement.conditions)
        }
        if let statement = ancestor.as(ForStmtSyntax.self), statement.body.id == child.id {
            return PatternNames.of(statement.pattern).contains(name)
        }
        if let switchCase = ancestor.as(SwitchCaseSyntax.self), case let .case(label) = switchCase.label {
            return label.caseItems.contains { PatternNames.of($0.pattern).contains(name) }
        }
        if let closure = ancestor.as(ClosureExprSyntax.self) {
            return closureParameterNames(closure).contains(name)
        }
        if let function = ancestor.as(FunctionDeclSyntax.self) {
            return parameterNames(function.signature.parameterClause).contains(name)
        }
        if let initializer = ancestor.as(InitializerDeclSyntax.self) {
            return parameterNames(initializer.signature.parameterClause).contains(name)
        }
        if let accessor = ancestor.as(AccessorDeclSyntax.self) {
            return accessorParameterName(accessor) == name
        }
        return false
    }

    private static func declares(_ name: String, item: CodeBlockItemSyntax) -> Bool {
        switch item.item {
        case let .decl(decl):
            guard let variable = decl.as(VariableDeclSyntax.self) else { return false }
            return variable.bindings.contains { PatternNames.of($0.pattern).contains(name) }
        case let .stmt(statement):
            guard let guardStatement = statement.as(GuardStmtSyntax.self) else { return false }
            return binds(name, guardStatement.conditions)
        default:
            return false
        }
    }

    private static func binds(_ name: String, _ conditions: ConditionElementListSyntax) -> Bool {
        conditions.contains { element in
            switch element.condition {
            case let .optionalBinding(binding):
                PatternNames.of(binding.pattern).contains(name)
            case let .matchingPattern(matching):
                PatternNames.of(matching.pattern).contains(name)
            default:
                false
            }
        }
    }

    private static func parameterNames(_ clause: FunctionParameterClauseSyntax) -> [String] {
        clause.parameters.map { ($0.secondName ?? $0.firstName).text }
    }

    private static func closureParameterNames(_ closure: ClosureExprSyntax) -> [String] {
        switch closure.signature?.parameterClause {
        case let .simpleInput(parameters):
            parameters.map(\.name.text)
        case let .parameterClause(clause):
            clause.parameters.map { ($0.secondName ?? $0.firstName).text }
        case nil:
            []
        }
    }

    private static func accessorParameterName(_ accessor: AccessorDeclSyntax) -> String? {
        if let parameters = accessor.parameters {
            return parameters.name.text
        }
        switch accessor.accessorSpecifier.text {
        case "set", "willSet":
            return "newValue"
        case "didSet":
            return "oldValue"
        default:
            return nil
        }
    }
}

private final class PatternNames: SyntaxVisitor {
    var names: [String] = []

    static func of(_ pattern: some SyntaxProtocol) -> [String] {
        let collector = PatternNames(viewMode: .sourceAccurate)
        collector.walk(pattern)
        return collector.names
    }

    override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.identifier.text)
        return .visitChildren
    }
}
