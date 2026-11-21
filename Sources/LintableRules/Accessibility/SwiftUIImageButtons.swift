import LintableKit
import SwiftSyntax

final class SwiftUIImageButtons: SyntaxVisitor {
    private static let trailingClosureLabelArguments: [String: Set<String>] = [
        "Button": ["action", "intent"],
        "Link": ["destination"],
        "NavigationLink": ["destination", "value"],
    ]

    let controls: Set<String>
    let labelModifiers: Set<String>
    let index: SyntaxIndex
    private(set) var violations: [Violation] = []
    private var labelledViewNames: Set<String> = []

    init(options: UnlabeledImageButtonRule.Options, index: SyntaxIndex) {
        controls = Set(options.swiftuiControls)
        labelModifiers = Set(options.labelModifiers)
        self.index = index
        super.init(viewMode: .sourceAccurate)
    }

    func run(on tree: SourceFileSyntax) {
        let collector = LabelledViewNameCollector(isLabelModifier: isLabelModifier)
        collector.walk(tree)
        labelledViewNames = collector.names
        walk(tree)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let control = controlName(of: node), controls.contains(control), let label = labelClosure(of: node, control: control) else {
            return .visitChildren
        }
        let content = ViewContent(statements: label.statements, isLabelModifier: isLabelModifier)
        guard content.showsOnlyImages,
              !SwiftUIModifiers.chain(after: ExprSyntax(node)).contains(where: isLabelModifier),
              !ownerIsLabelled(node),
              !LocalizationSyntax.isInDebugOrPreviewCode(node, index: index)
        else {
            return .visitChildren
        }
        let message = "This `\(control)` shows only an image, so VoiceOver can only read the image's name. "
            + "Add `.accessibilityLabel(Text(…))` with a localized description of what it does."
        violations.append(Violation(at: node, message: message))
        return .visitChildren
    }

    private func controlName(of call: FunctionCallExprSyntax) -> String? {
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self),
           member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "SwiftUI"
        {
            return member.declName.baseName.text
        }
        return nil
    }

    private func labelClosure(of call: FunctionCallExprSyntax, control: String) -> ClosureExprSyntax? {
        if let argument = call.arguments.first(where: { $0.label?.text == "label" }) {
            return argument.expression.as(ClosureExprSyntax.self)
        }
        if let element = call.additionalTrailingClosures.first(where: { $0.label.text == "label" }) {
            return element.closure
        }
        let labelArguments = Self.trailingClosureLabelArguments[control] ?? []
        guard let trailing = call.trailingClosure,
              call.arguments.contains(where: { argument in argument.label.map { labelArguments.contains($0.text) } ?? false })
        else {
            return nil
        }
        return trailing
    }

    private func isLabelModifier(_ modifier: FunctionCallExprSyntax) -> Bool {
        guard let name = modifier.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text else { return false }
        if name == "accessibility" {
            return modifier.arguments.contains { $0.label?.text == "label" }
        }
        return labelModifiers.contains(name)
    }

    private func ownerIsLabelled(_ call: FunctionCallExprSyntax) -> Bool {
        let outermost = SwiftUIModifiers.chain(after: ExprSyntax(call)).last.map(Syntax.init) ?? Syntax(call)
        guard let owner = SwiftUIModifiers.ownerName(ofSoleExpression: outermost) else { return false }
        return labelledViewNames.contains(owner)
    }
}

private struct ViewContent {
    private static let textViews: Set<String> = ["Text", "Label", "TextField", "SecureField"]
    private static let imageViews: Set<String> = ["Image", "AsyncImage"]
    private static let containers: Set<String> = ["HStack", "VStack", "ZStack", "Group", "LazyHStack", "LazyVStack", "ViewThatFits"]
    private static let silentViews: Set<String> = [
        "Spacer", "Divider", "Color", "Circle", "Capsule", "Ellipse", "Rectangle", "RoundedRectangle", "EmptyView",
    ]

    private(set) var images = 0
    private(set) var hasText = false
    private(set) var hasUnknownView = false
    private(set) var isLabelled = false
    private let isLabelModifier: (FunctionCallExprSyntax) -> Bool

    init(statements: CodeBlockItemListSyntax, isLabelModifier: @escaping (FunctionCallExprSyntax) -> Bool) {
        self.isLabelModifier = isLabelModifier
        add(statements)
    }

    var showsOnlyImages: Bool {
        images > 0 && !hasText && !hasUnknownView && !isLabelled
    }

    private mutating func add(_ statements: CodeBlockItemListSyntax) {
        for statement in statements {
            switch statement.item {
            case let .expr(expression):
                add(expression)
            case let .stmt(stmt):
                if let expression = stmt.as(ExpressionStmtSyntax.self)?.expression {
                    add(expression)
                } else {
                    hasUnknownView = true
                }
            case .decl:
                continue
            }
        }
    }

    private mutating func add(_ expression: ExprSyntax) {
        if let ifExpression = expression.as(IfExprSyntax.self) {
            add(ifExpression)
        } else if let switchExpression = expression.as(SwitchExprSyntax.self) {
            for switchCase in switchExpression.cases {
                if let caseSyntax = switchCase.as(SwitchCaseSyntax.self) {
                    add(caseSyntax.statements)
                } else {
                    hasUnknownView = true
                }
            }
        } else if let ternary = expression.as(TernaryExprSyntax.self) {
            add(ternary.thenExpression)
            add(ternary.elseExpression)
        } else if let call = expression.as(FunctionCallExprSyntax.self) {
            add(call)
        } else if !Self.isSilentConstant(expression) {
            hasUnknownView = true
        }
    }

    private static func isSilentConstant(_ expression: ExprSyntax) -> Bool {
        guard let base = expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) else { return false }
        return silentViews.contains(base.baseName.text)
    }

    private mutating func add(_ ifExpression: IfExprSyntax) {
        add(ifExpression.body.statements)
        switch ifExpression.elseBody {
        case let .ifExpr(next):
            add(next)
        case let .codeBlock(block):
            add(block.statements)
        case nil:
            break
        }
    }

    private mutating func add(_ call: FunctionCallExprSyntax) {
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
            if isLabelModifier(call) {
                isLabelled = true
            }
            add(base)
            return
        }
        guard let name = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else {
            hasUnknownView = true
            return
        }
        if Self.imageViews.contains(name) {
            if call.arguments.contains(where: { $0.label?.text == "label" }) {
                isLabelled = true
            }
            images += 1
        } else if Self.textViews.contains(name) {
            hasText = true
        } else if Self.containers.contains(name) {
            if let content = call.trailingClosure ?? call.arguments.first(where: { $0.label?.text == "content" })?.expression.as(ClosureExprSyntax.self) {
                add(content.statements)
            }
        } else if !Self.silentViews.contains(name) {
            hasUnknownView = true
        }
    }
}

enum SwiftUIModifiers {
    static func chain(after expression: ExprSyntax) -> [FunctionCallExprSyntax] {
        var modifiers: [FunctionCallExprSyntax] = []
        var current = Syntax(expression)
        while let member = current.parent?.as(MemberAccessExprSyntax.self), member.base?.id == current.id,
              let call = member.parent?.as(FunctionCallExprSyntax.self), call.calledExpression.id == member.id
        {
            modifiers.append(call)
            current = Syntax(call)
        }
        return modifiers
    }

    static func root(ofModified expression: ExprSyntax) -> ExprSyntax {
        var current = expression
        while let call = current.as(FunctionCallExprSyntax.self), let member = call.calledExpression.as(MemberAccessExprSyntax.self),
              let base = member.base
        {
            current = base
        }
        return current
    }

    static func ownerName(ofSoleExpression expression: Syntax) -> String? {
        var node = expression
        if let returnStatement = node.parent?.as(ReturnStmtSyntax.self) {
            node = Syntax(returnStatement)
        }
        guard let item = node.parent?.as(CodeBlockItemSyntax.self), let list = item.parent?.as(CodeBlockItemListSyntax.self),
              list.count == 1
        else {
            return nil
        }
        if let accessorBlock = list.parent?.as(AccessorBlockSyntax.self) {
            return accessorBlock.parent?.as(PatternBindingSyntax.self).flatMap(name(of:))
        }
        guard let block = list.parent?.as(CodeBlockSyntax.self) else { return nil }
        if let function = block.parent?.as(FunctionDeclSyntax.self) {
            return function.name.text
        }
        if let accessor = block.parent?.as(AccessorDeclSyntax.self), accessor.accessorSpecifier.tokenKind == .keyword(.get),
           let binding = accessor.parent?.parent?.parent?.as(PatternBindingSyntax.self)
        {
            return name(of: binding)
        }
        return nil
    }

    private static func name(of binding: PatternBindingSyntax) -> String? {
        binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
}

private final class LabelledViewNameCollector: SyntaxVisitor {
    let isLabelModifier: (FunctionCallExprSyntax) -> Bool
    var names: Set<String> = []

    init(isLabelModifier: @escaping (FunctionCallExprSyntax) -> Bool) {
        self.isLabelModifier = isLabelModifier
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isLabelModifier(node), let base = node.calledExpression.as(MemberAccessExprSyntax.self)?.base else {
            return .visitChildren
        }
        let root = SwiftUIModifiers.root(ofModified: base)
        if let reference = root.as(DeclReferenceExprSyntax.self) {
            names.insert(reference.baseName.text)
        } else if let member = root.as(MemberAccessExprSyntax.self), member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" {
            names.insert(member.declName.baseName.text)
        } else if let call = root.as(FunctionCallExprSyntax.self), let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            names.insert(reference.baseName.text)
        }
        return .visitChildren
    }
}
