import SwiftSyntax

public final class SyntaxIndex: Sendable {
    public let tree: SourceFileSyntax
    public let functions: [FunctionSignature]
    private let classesByName: [String: [TypeContext]]
    private let callsByName: [String: [CallSite]]
    private let referencesByName: [String: [Reference]]

    init(tree: SourceFileSyntax) {
        self.tree = tree
        let declarations = DeclarationCollector(viewMode: .sourceAccurate)
        declarations.walk(tree)
        functions = declarations.functions
        classesByName = Dictionary(grouping: declarations.classes, by: \.name)
        let uses = UseCollector(functionNames: Set(declarations.functions.map(\.baseName)))
        uses.walk(tree)
        callsByName = Dictionary(grouping: uses.calls, by: \.baseName)
        referencesByName = Dictionary(grouping: uses.references, by: \.baseName)
    }

    public func scope(of node: some SyntaxProtocol) -> Scope {
        scopes(of: node)[0]
    }

    public func scopes(of node: some SyntaxProtocol) -> [Scope] {
        var result: [Scope] = []
        var child = Syntax(node)
        var current = child.parent
        while let ancestor = current {
            if let scope = Scope.make(ancestor, child: child) {
                result.append(scope)
            }
            child = ancestor
            current = ancestor.parent
        }
        result.append(Scope(kind: .topLevel, node: Syntax(tree), name: "top-level code", signature: nil))
        return result
    }

    public func signature(of function: FunctionDeclSyntax) -> FunctionSignature {
        FunctionSignature(function)
    }

    public func signature(of initializer: InitializerDeclSyntax) -> FunctionSignature {
        FunctionSignature(initializer)
    }

    public func types(of node: some SyntaxProtocol) -> [TypeContext] {
        var result: [TypeContext] = []
        var current = Syntax(node).parent
        while let ancestor = current {
            if let type = TypeContext(ancestor) {
                result.append(type)
            }
            current = ancestor.parent
        }
        return result
    }

    public func inheritsFrom(_ type: TypeContext, anyOf names: Set<String>) -> Bool {
        var visited: Set<String> = [type.name]
        var pending = type.inheritedTypes
        if type.kind == .extension {
            pending += (classesByName[type.name] ?? []).flatMap(\.inheritedTypes)
        }
        while let next = pending.popLast() {
            if names.contains(next) {
                return true
            }
            guard visited.insert(next).inserted else { continue }
            pending += (classesByName[next] ?? []).flatMap(\.inheritedTypes)
        }
        return false
    }

    public func calls(named baseName: String) -> [CallSite] {
        callsByName[baseName] ?? []
    }

    public func calls(to signature: FunctionSignature) -> [CallSite] {
        calls(named: signature.baseName).filter { $0.matches(signature) }
    }

    public func references(to signature: FunctionSignature) -> [Reference] {
        (referencesByName[signature.baseName] ?? []).filter { $0.matches(signature) }
    }

    public func invocation(of closure: ClosureExprSyntax) -> ClosureInvocation? {
        guard let parent = closure.parent else { return nil }
        var call: FunctionCallExprSyntax?
        if let candidate = parent.as(FunctionCallExprSyntax.self), candidate.trailingClosure?.id == closure.id {
            call = candidate
        } else if let argument = parent.as(LabeledExprSyntax.self) {
            call = argument.parent?.parent?.as(FunctionCallExprSyntax.self)
        } else if let element = parent.as(MultipleTrailingClosureElementSyntax.self) {
            call = element.parent?.parent?.as(FunctionCallExprSyntax.self)
        }
        guard let call else { return nil }
        return ClosureInvocation(calleeComponents: ClosureInvocation.components(of: call.calledExpression), call: Syntax(call))
    }

    public func assignmentTarget(of expression: InfixOperatorExprSyntax) -> AssignmentTarget? {
        let operatorText: String
        if expression.operator.is(AssignmentExprSyntax.self) {
            operatorText = "="
        } else if let binary = expression.operator.as(BinaryOperatorExprSyntax.self),
                  AssignmentTarget.operators.contains(binary.operator.text)
        {
            operatorText = binary.operator.text
        } else {
            return nil
        }
        return AssignmentTarget.make(left: expression.leftOperand, operatorText: operatorText)
    }

    public func assignmentTarget(of sequence: SequenceExprSyntax) -> AssignmentTarget? {
        let elements = Array(sequence.elements)
        guard elements.count >= 3 else { return nil }
        if elements[1].is(AssignmentExprSyntax.self) {
            return AssignmentTarget.make(left: elements[0], operatorText: "=")
        }
        if let binary = elements[1].as(BinaryOperatorExprSyntax.self), AssignmentTarget.operators.contains(binary.operator.text) {
            return AssignmentTarget.make(left: elements[0], operatorText: binary.operator.text)
        }
        return nil
    }
}

private final class DeclarationCollector: SyntaxVisitor {
    var functions: [FunctionSignature] = []
    var classes: [TypeContext] = []

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        functions.append(FunctionSignature(node))
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if let type = TypeContext(Syntax(node)) {
            classes.append(type)
        }
        return .visitChildren
    }
}

private final class UseCollector: SyntaxVisitor {
    let functionNames: Set<String>
    var calls: [CallSite] = []
    var references: [Reference] = []

    init(functionNames: Set<String>) {
        self.functionNames = functionNames
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let callee = node.calledExpression
        let baseName: String
        let receiver: CallSite.Receiver
        if let reference = callee.as(DeclReferenceExprSyntax.self) {
            baseName = reference.baseName.text
            receiver = .implicit
        } else if let member = callee.as(MemberAccessExprSyntax.self) {
            baseName = member.declName.baseName.text
            if let base = member.base {
                receiver = base.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" ? .explicitSelf : .other(base.trimmedDescription)
            } else {
                receiver = .other(".")
            }
        } else {
            return .visitChildren
        }
        calls.append(CallSite(
            baseName: baseName,
            argumentLabels: node.arguments.map { $0.label?.text },
            hasTrailingClosure: node.trailingClosure != nil,
            additionalTrailingClosureLabels: node.additionalTrailingClosures.map(\.label.text),
            receiver: receiver,
            node: Syntax(node)
        ))
        return .visitChildren
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.macroName.text == "selector", let argument = node.arguments.last?.expression else {
            return .visitChildren
        }
        let name: DeclReferenceExprSyntax?
        if let reference = argument.as(DeclReferenceExprSyntax.self) {
            name = reference
        } else {
            name = argument.as(MemberAccessExprSyntax.self)?.declName
        }
        if let name {
            references.append(Reference(
                kind: .selector,
                baseName: name.baseName.text,
                argumentLabels: name.argumentNames.map { $0.arguments.map { $0.name.tokenKind == .wildcard ? nil : $0.name.text } },
                node: Syntax(node)
            ))
        }
        return .skipChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        guard functionNames.contains(node.baseName.text), !isCallee(node) else {
            return .visitChildren
        }
        references.append(Reference(
            kind: .value,
            baseName: node.baseName.text,
            argumentLabels: node.argumentNames.map { $0.arguments.map { $0.name.tokenKind == .wildcard ? nil : $0.name.text } },
            node: Syntax(node)
        ))
        return .visitChildren
    }

    private func isCallee(_ node: DeclReferenceExprSyntax) -> Bool {
        var callee = Syntax(node)
        if let member = node.parent?.as(MemberAccessExprSyntax.self), member.declName.id == node.id {
            callee = Syntax(member)
        }
        guard let call = callee.parent?.as(FunctionCallExprSyntax.self) else { return false }
        return call.calledExpression.id == callee.id
    }
}
