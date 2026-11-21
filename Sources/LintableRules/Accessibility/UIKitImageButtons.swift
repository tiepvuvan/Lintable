import LintableKit
import SwiftSyntax

private struct ButtonKey: Hashable {
    let group: String
    let path: [String]
    let local: AbsolutePosition?

    var displayName: String {
        path.joined(separator: ".")
    }

    var lastComponent: String? {
        path.count > 1 ? path.last : nil
    }

    var labelsByName: String? {
        local == nil || path.count > 1 ? path.last : nil
    }
}

private struct ImageEvent {
    let key: ButtonKey
    let node: Syntax
}

private struct ConfigurationLink {
    let button: ButtonKey
    let configuration: ButtonKey
    let node: Syntax
}

final class UIKitImageButtons: SyntaxVisitor {
    private static let titleCalls: Set<String> = ["setTitle", "setAttributedTitle"]
    private static let configurationTitles: Set<String> = ["title", "attributedTitle"]

    let labelProperties: Set<String>
    let index: SyntaxIndex
    private let resolver: ReceiverResolver
    private var images: [ImageEvent] = []
    private var anonymousBarItems: [Syntax] = []
    private var labelled: Set<ButtonKey> = []
    private var configurationsWithImage: Set<ButtonKey> = []
    private var configurationsWithTitle: Set<ButtonKey> = []
    private var configurationLinks: [ConfigurationLink] = []
    private var aliases = KeyAliases()

    init(options: UnlabeledImageButtonRule.Options, index: SyntaxIndex) {
        labelProperties = Set(options.labelProperties)
        self.index = index
        resolver = ReceiverResolver(index: index)
        super.init(viewMode: .sourceAccurate)
    }

    func findViolations() -> [Violation] {
        var images = images
        var labelled = labelled
        for link in configurationLinks {
            if configurationsWithImage.contains(link.configuration) {
                images.append(ImageEvent(key: link.button, node: link.node))
            }
            if configurationsWithTitle.contains(link.configuration) {
                labelled.insert(link.button)
            }
        }
        let labelledRoots = Set(labelled.map { aliases.root(of: $0) })
        let labelledNames = Set(labelled.compactMap(\.labelsByName))
        var reported: Set<ButtonKey> = []
        var found: [Violation] = []
        for event in images.sorted(by: { $0.node.position < $1.node.position }) {
            let root = aliases.root(of: event.key)
            guard !labelledRoots.contains(root),
                  root.local == nil || root.path.count > 1 || (resolver.createsObject(root) && !resolver.escapes(root)),
                  root.lastComponent.map({ !labelledNames.contains($0) }) ?? true,
                  reported.insert(root).inserted,
                  !LocalizationSyntax.isInDebugOrPreviewCode(event.node, index: index)
            else {
                continue
            }
            found.append(Violation(at: event.node, message: Self.message(naming: "`\(root.displayName)`")))
        }
        for node in anonymousBarItems where !LocalizationSyntax.isInDebugOrPreviewCode(node, index: index) {
            found.append(Violation(at: node, message: Self.message(naming: "This bar button item")))
        }
        return found
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
            recordMethodCall(named: member.declName.baseName.text, on: base, call: node)
        } else if let name = LocalizationSyntax.calleeName(node) {
            recordInitializer(named: name, call: node)
        }
        return .visitChildren
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if let target = index.assignmentTarget(of: node), target.operatorText == "=" {
            recordAssignment(to: target, value: node.rightOperand, node: Syntax(node))
        }
        return .visitChildren
    }

    private func recordMethodCall(named name: String, on base: ExprSyntax, call: FunctionCallExprSyntax) {
        let arguments = Array(call.arguments)
        guard arguments.count == 2, arguments[0].label == nil, arguments[1].label?.text == "for",
              let key = resolver.key(of: base)
        else {
            return
        }
        if name == "setImage", !Self.isEmpty(arguments[0].expression) {
            images.append(ImageEvent(key: key, node: Syntax(call)))
        } else if Self.titleCalls.contains(name), !Self.isEmpty(arguments[0].expression) {
            labelled.insert(key)
        }
    }

    private func recordInitializer(named name: String, call: FunctionCallExprSyntax) {
        switch name {
        case "UIBarButtonItem":
            guard call.arguments.first?.label?.text == "image",
                  !call.arguments.contains(where: { $0.label?.text == "title" && !Self.isEmpty($0.expression) })
            else {
                return
            }
            if let key = boundKey(of: call) {
                images.append(ImageEvent(key: key, node: Syntax(call)))
            } else if !returnsFromFunction(call) {
                anonymousBarItems.append(Syntax(call))
            }
        case "UIButton":
            guard let configuration = call.arguments.first(where: { $0.label?.text == "configuration" })?.expression,
                  let configurationKey = resolver.key(of: configuration), let key = boundKey(of: call)
            else {
                return
            }
            configurationLinks.append(ConfigurationLink(button: key, configuration: configurationKey, node: Syntax(call)))
        default:
            return
        }
    }

    private func recordAssignment(to target: AssignmentTarget, value: ExprSyntax, node: Syntax) {
        recordAlias(target: target, value: value)
        guard let property = target.members.last, let receiver = resolver.key(of: target, droppingLast: 1) else { return }
        let parent = target.members.dropLast().last
        if property == "configuration" {
            if let configuration = resolver.key(of: value) {
                configurationLinks.append(ConfigurationLink(button: receiver, configuration: configuration, node: node))
            }
        } else if property == "isAccessibilityElement" {
            if value.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind == .keyword(.false) {
                labelled.insert(receiver)
            }
        } else if !Self.isEmpty(value) {
            recordValue(property: property, parent: parent, target: target, receiver: receiver, node: node)
        }
    }

    private func recordValue(property: String, parent: String?, target: AssignmentTarget, receiver: ButtonKey, node: Syntax) {
        let isNested = parent == "configuration" || parent == "titleLabel"
        if isNested, let button = resolver.key(of: target, droppingLast: 2) {
            if property == "image", parent == "configuration" {
                images.append(ImageEvent(key: button, node: node))
            } else if Self.configurationTitles.contains(property) || (property == "text" && parent == "titleLabel") {
                labelled.insert(button)
            }
        } else if property == "image" {
            configurationsWithImage.insert(receiver)
        } else if Self.configurationTitles.contains(property) {
            configurationsWithTitle.insert(receiver)
            labelled.insert(receiver)
        } else if labelProperties.contains(property) {
            labelled.insert(receiver)
        }
    }

    private func recordAlias(target: AssignmentTarget, value: ExprSyntax) {
        guard let assigned = resolver.key(of: value), assigned.local != nil, let key = resolver.key(of: target, droppingLast: 0) else {
            return
        }
        aliases.join(assigned, key)
    }

    private func boundKey(of call: FunctionCallExprSyntax) -> ButtonKey? {
        if let binding = call.parent?.as(InitializerClauseSyntax.self)?.parent?.as(PatternBindingSyntax.self),
           let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
        {
            return resolver.key(declaredBy: name, in: binding)
        }
        if let assignment = call.parent?.as(InfixOperatorExprSyntax.self), assignment.rightOperand.id == call.id,
           let target = index.assignmentTarget(of: assignment)
        {
            return resolver.key(of: target, droppingLast: 0)
        }
        return nil
    }

    private func returnsFromFunction(_ call: FunctionCallExprSyntax) -> Bool {
        call.parent?.is(ReturnStmtSyntax.self) ?? false
    }

    private static func message(naming subject: String) -> String {
        "\(subject) shows only an image, so VoiceOver can only read the image's name. "
            + "Set its `accessibilityLabel` to a localized description of what it does."
    }

    private static func isEmpty(_ expression: ExprSyntax) -> Bool {
        if expression.is(NilLiteralExprSyntax.self) {
            return true
        }
        if let literal = expression.as(StringLiteralExprSyntax.self) {
            return literal.segments.allSatisfy { $0.as(StringSegmentSyntax.self)?.content.text.isEmpty ?? false }
        }
        return false
    }
}

private struct KeyAliases {
    private var parents: [ButtonKey: ButtonKey] = [:]

    func root(of key: ButtonKey) -> ButtonKey {
        var current = key
        while let parent = parents[current], parent != current {
            current = parent
        }
        return current
    }

    mutating func join(_ local: ButtonKey, _ other: ButtonKey) {
        let localRoot = root(of: local)
        let otherRoot = root(of: other)
        guard localRoot != otherRoot else { return }
        if localRoot.local != nil {
            parents[localRoot] = otherRoot
        } else {
            parents[otherRoot] = localRoot
        }
    }
}

private struct ReceiverResolver {
    let index: SyntaxIndex

    func key(of expression: ExprSyntax) -> ButtonKey? {
        var members: [String] = []
        var current = expression
        while true {
            if let member = current.as(MemberAccessExprSyntax.self) {
                guard let base = member.base else { return nil }
                members.insert(member.declName.baseName.text, at: 0)
                current = base
            } else if let optional = current.as(OptionalChainingExprSyntax.self) {
                current = optional.expression
            } else if let forced = current.as(ForceUnwrapExprSyntax.self) {
                current = forced.expression
            } else if let reference = current.as(DeclReferenceExprSyntax.self) {
                return key(root: reference.baseName.text, members: members, at: Syntax(expression))
            } else {
                return nil
            }
        }
    }

    func key(of target: AssignmentTarget, droppingLast count: Int) -> ButtonKey? {
        guard target.members.count >= count else { return nil }
        let members = Array(target.members.dropLast(count))
        switch target.root {
        case .explicitSelf:
            return members.isEmpty ? nil : ButtonKey(group: group(of: target.node), path: members, local: nil)
        case let .name(name):
            return key(root: name, members: members, at: target.node)
        case .other:
            return nil
        }
    }

    func key(declaredBy name: TokenSyntax, in binding: PatternBindingSyntax) -> ButtonKey? {
        if binding.parent?.parent?.parent?.is(MemberBlockItemSyntax.self) ?? false {
            return ButtonKey(group: group(of: Syntax(binding)), path: [name.text], local: nil)
        }
        return localKey(name.text, members: [], declaration: Syntax(name), at: Syntax(binding))
    }

    func createsObject(_ key: ButtonKey) -> Bool {
        guard let position = key.local, let token = index.tree.token(at: position),
              let value = token.parent?.as(IdentifierPatternSyntax.self)?.parent?.as(PatternBindingSyntax.self)?.initializer?.value,
              let call = value.as(FunctionCallExprSyntax.self)
        else {
            return false
        }
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text.first?.isUppercase ?? false
        }
        guard let member = call.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        if member.declName.baseName.text == "init" {
            return true
        }
        return member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text.first?.isUppercase ?? false
    }

    func escapes(_ key: ButtonKey) -> Bool {
        guard let position = key.local, let name = key.path.first,
              let token = index.tree.token(at: position), let body = enclosingBody(of: Syntax(token))
        else {
            return false
        }
        return ReturnFinder(name: name).returns(in: body)
    }

    private func key(root name: String, members: [String], at node: Syntax) -> ButtonKey? {
        if name == "self" {
            return members.isEmpty ? nil : ButtonKey(group: group(of: node), path: members, local: nil)
        }
        if name.hasPrefix("$") {
            return nil
        }
        switch LocalBinding.find(name, at: node) {
        case let .local(declaration):
            return localKey(name, members: members, declaration: declaration, at: node)
        case .parameter:
            return nil
        case nil:
            return ButtonKey(group: group(of: node), path: [name] + members, local: nil)
        }
    }

    private func localKey(_ name: String, members: [String], declaration: Syntax, at node: Syntax) -> ButtonKey {
        if let property = propertyInitialized(byReturning: name, declaredAt: declaration) {
            return ButtonKey(group: group(of: node), path: [property] + members, local: nil)
        }
        return ButtonKey(group: group(of: node), path: [name] + members, local: declaration.positionAfterSkippingLeadingTrivia)
    }

    private func group(of node: Syntax) -> String {
        index.types(of: node).first?.name ?? ""
    }

    private func propertyInitialized(byReturning name: String, declaredAt declaration: Syntax) -> String? {
        guard let closure = declaration.ancestor(ClosureExprSyntax.self),
              let call = closure.parent?.as(FunctionCallExprSyntax.self), call.calledExpression.id == closure.id,
              let binding = call.parent?.as(InitializerClauseSyntax.self)?.parent?.as(PatternBindingSyntax.self),
              let property = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              ReturnFinder(name: name).returns(in: Syntax(closure))
        else {
            return nil
        }
        return property
    }

    private func enclosingBody(of node: Syntax) -> Syntax? {
        var current = node.parent
        while let ancestor = current {
            if ancestor.is(ClosureExprSyntax.self) || ancestor.is(FunctionDeclSyntax.self) || ancestor.is(AccessorDeclSyntax.self)
                || ancestor.is(InitializerDeclSyntax.self)
            {
                return ancestor
            }
            current = ancestor.parent
        }
        return nil
    }
}

private struct ReturnFinder {
    let name: String

    func returns(in body: Syntax) -> Bool {
        let visitor = ReturnVisitor(name: name, body: body)
        visitor.walk(body)
        return visitor.found
    }
}

private final class ReturnVisitor: SyntaxVisitor {
    let name: String
    let body: Syntax
    var found = false

    init(name: String, body: Syntax) {
        self.name = name
        self.body = body
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        Syntax(node).id == body.id ? .visitChildren : .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        Syntax(node).id == body.id ? .visitChildren : .skipChildren
    }

    override func visit(_ node: ReturnStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.expression?.as(DeclReferenceExprSyntax.self)?.baseName.text == name {
            found = true
        }
        return .skipChildren
    }
}

private enum LocalBinding {
    case local(Syntax)
    case parameter

    static func find(_ name: String, at node: Syntax) -> LocalBinding? {
        var child = node
        var current = node.parent
        while let ancestor = current {
            if ancestor.is(MemberBlockSyntax.self) {
                return nil
            }
            if let found = binding(of: name, in: ancestor, before: child) {
                return found
            }
            child = ancestor
            current = ancestor.parent
        }
        return nil
    }

    private static func binding(of name: String, in ancestor: Syntax, before child: Syntax) -> LocalBinding? {
        if let list = ancestor.as(CodeBlockItemListSyntax.self) {
            for item in list {
                if item.id == child.id {
                    return nil
                }
                if let declaration = declaration(of: name, in: item) {
                    return .local(declaration)
                }
            }
            return nil
        }
        if let closure = ancestor.as(ClosureExprSyntax.self), closureParameters(closure).contains(name) {
            return .parameter
        }
        if let function = ancestor.as(FunctionDeclSyntax.self), parameters(function.signature.parameterClause).contains(name) {
            return .parameter
        }
        if let initializer = ancestor.as(InitializerDeclSyntax.self), parameters(initializer.signature.parameterClause).contains(name) {
            return .parameter
        }
        if let loop = ancestor.as(ForStmtSyntax.self), loop.body.id == child.id, PatternNames.of(loop.pattern).contains(name) {
            return .parameter
        }
        if let statement = ancestor.as(IfExprSyntax.self), statement.body.id == child.id, let bound = bound(name, statement.conditions) {
            return .local(bound)
        }
        return nil
    }

    private static func declaration(of name: String, in item: CodeBlockItemSyntax) -> Syntax? {
        switch item.item {
        case let .decl(decl):
            guard let variable = decl.as(VariableDeclSyntax.self) else { return nil }
            for binding in variable.bindings {
                if let identifier = binding.pattern.as(IdentifierPatternSyntax.self), identifier.identifier.text == name {
                    return Syntax(identifier.identifier)
                }
            }
            return nil
        case let .stmt(statement):
            guard let guardStatement = statement.as(GuardStmtSyntax.self) else { return nil }
            return bound(name, guardStatement.conditions)
        default:
            return nil
        }
    }

    private static func bound(_ name: String, _ conditions: ConditionElementListSyntax) -> Syntax? {
        for element in conditions {
            if case let .optionalBinding(binding) = element.condition,
               let identifier = binding.pattern.as(IdentifierPatternSyntax.self), identifier.identifier.text == name
            {
                return Syntax(identifier.identifier)
            }
        }
        return nil
    }

    private static func parameters(_ clause: FunctionParameterClauseSyntax) -> [String] {
        clause.parameters.map { ($0.secondName ?? $0.firstName).text }
    }

    private static func closureParameters(_ closure: ClosureExprSyntax) -> [String] {
        switch closure.signature?.parameterClause {
        case let .simpleInput(parameters):
            parameters.map(\.name.text)
        case let .parameterClause(clause):
            clause.parameters.map { ($0.secondName ?? $0.firstName).text }
        case nil:
            []
        }
    }
}

private enum PatternNames {
    static func of(_ pattern: PatternSyntax) -> [String] {
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            return [identifier.identifier.text]
        }
        if let tuple = pattern.as(TuplePatternSyntax.self) {
            return tuple.elements.flatMap { of($0.pattern) }
        }
        if let binding = pattern.as(ValueBindingPatternSyntax.self) {
            return of(binding.pattern)
        }
        return []
    }
}

private extension Syntax {
    func ancestor<T: SyntaxProtocol>(_: T.Type) -> T? {
        var current = parent
        while let node = current {
            if let match = node.as(T.self) {
                return match
            }
            current = node.parent
        }
        return nil
    }
}
