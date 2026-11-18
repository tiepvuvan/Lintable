import LintableKit
import SwiftSyntax

struct LayoutLifecycleAnalysis {
    private enum Context {
        case allowed
        case helper(FunctionSignature)
        case outside(String)
    }

    private static let geometryParts: Set<String> = ["origin", "size", "x", "y", "width", "height"]

    let file: LintFile
    let options: LayoutLifecycleOptions
    private let properties: Set<String>
    private let layoutMethods: Set<String>
    private let transitionMethods: Set<String>
    private let exemptSuperclasses: Set<String>

    init(file: LintFile, options: LayoutLifecycleOptions) {
        self.file = file
        self.options = options
        properties = Set(options.properties + (options.checkTransform ? ["transform"] : []))
        layoutMethods = Set(options.layoutMethods)
        transitionMethods = options.exemptTransitions ? Set(options.transitionMethods) : []
        exemptSuperclasses = Set(options.exemptSuperclasses)
    }

    func violations() -> [Violation] {
        let writes = WriteCollector(index: file.index)
        writes.walk(file.tree)
        let helpers = file.index.functions.filter(isHelper)
        let privateHelpers = helpers.filter { $0.accessLevel <= .fileprivate }
        let allowedHelpers = resolveAllowedHelpers(privateHelpers)

        var violations: [Violation] = []
        var publicHelpersWithWrites: [FunctionSignature] = []
        for write in writes.found {
            guard let path = writtenPath(write.target, at: write.node) else { continue }
            switch context(of: write.node, allowedHelpers: allowedHelpers) {
            case .allowed:
                continue
            case let .helper(signature):
                if signature.accessLevel > .fileprivate, !publicHelpersWithWrites.contains(signature) {
                    publicHelpersWithWrites.append(signature)
                }
            case let .outside(name):
                violations.append(Violation(at: write.target.node, message: Message.write(path, in: name, prefix: options.helperPrefix)))
            }
        }
        for helper in publicHelpersWithWrites {
            violations.append(Violation(at: nameToken(of: helper), message: Message.notPrivate(helper.displayName)))
        }
        for helper in privateHelpers where !allowedHelpers.contains(helper) {
            violations += helperViolations(helper, allowedHelpers: allowedHelpers)
        }
        return violations
    }

    private func helperViolations(_ helper: FunctionSignature, allowedHelpers: Set<FunctionSignature>) -> [Violation] {
        let valueMessage = Message.usedAsValue(helper.displayName)
        var violations: [Violation] = []
        if helper.isObjC {
            violations.append(Violation(at: nameToken(of: helper), message: valueMessage))
        }
        for reference in file.index.references(to: helper) {
            violations.append(Violation(at: reference.node, message: valueMessage))
        }
        for call in file.index.calls(to: helper) {
            guard case let .outside(name) = context(of: call.node, allowedHelpers: allowedHelpers) else { continue }
            violations.append(Violation(at: call.node, message: Message.helperCall(helper.displayName, from: name)))
        }
        return violations
    }

    private func resolveAllowedHelpers(_ helpers: [FunctionSignature]) -> Set<FunctionSignature> {
        var allowed: Set<FunctionSignature> = []
        var changed = true
        while changed {
            changed = false
            for helper in helpers where !allowed.contains(helper) {
                guard !helper.isObjC, file.index.references(to: helper).isEmpty else { continue }
                let calls = file.index.calls(to: helper)
                guard !calls.isEmpty else { continue }
                let everyCallIsInLayout = calls.allSatisfy { call in
                    switch context(of: call.node, allowedHelpers: allowed) {
                    case .allowed:
                        true
                    case let .helper(caller):
                        allowed.contains(caller)
                    case .outside:
                        false
                    }
                }
                if everyCallIsInLayout {
                    allowed.insert(helper)
                    changed = true
                }
            }
        }
        return allowed
    }

    private func context(of node: Syntax, allowedHelpers: Set<FunctionSignature>) -> Context {
        if file.index.types(of: node).contains(where: { file.index.inheritsFrom($0, anyOf: exemptSuperclasses) }) {
            return .allowed
        }
        for scope in file.index.scopes(of: node) {
            switch scope.kind {
            case .closure:
                guard let closure = scope.node.as(ClosureExprSyntax.self),
                      let invocation = file.index.invocation(of: closure),
                      options.deferredCalls.contains(where: invocation.matches)
                else { continue }
                return .outside("a closure passed to `\(invocation.calleeName)`")
            case .function:
                guard let signature = scope.signature else { return .outside(scope.name) }
                if scope.isLocalFunction {
                    continue
                }
                if layoutMethods.contains(signature.displayName) || transitionMethods.contains(signature.displayName) {
                    return .allowed
                }
                if isHelper(signature) {
                    return allowedHelpers.contains(signature) ? .allowed : .helper(signature)
                }
                return .outside(scope.name)
            default:
                return .outside(scope.name)
            }
        }
        return .outside("top-level code")
    }

    private func isHelper(_ signature: FunctionSignature) -> Bool {
        let prefix = options.helperPrefix
        guard !prefix.isEmpty,
              !signature.isOverride,
              !layoutMethods.contains(signature.displayName),
              !transitionMethods.contains(signature.displayName),
              signature.baseName.hasPrefix(prefix),
              let next = signature.baseName.dropFirst(prefix.count).first
        else {
            return false
        }
        return next.isUppercase
    }

    private func writtenPath(_ target: AssignmentTarget, at node: Syntax) -> String? {
        let path = target.path
        guard let index = path.firstIndex(where: properties.contains),
              path[(index + 1)...].allSatisfy(Self.geometryParts.contains)
        else {
            return nil
        }
        let isSelfProperty: Bool
        switch target.root {
        case let .name(name) where index == 0:
            if file.index.isLocalVariable(named: name, at: node) {
                return nil
            }
            isSelfProperty = true
        case .explicitSelf where index == 0:
            isSelfProperty = true
        default:
            isSelfProperty = false
        }
        if isSelfProperty, let type = file.index.types(of: node).first(where: { $0.kind != .extension }), type.isValueType {
            return nil
        }
        return path[index...].joined(separator: ".")
    }

    private func nameToken(of signature: FunctionSignature) -> Syntax {
        signature.node.as(FunctionDeclSyntax.self).map { Syntax($0.name) } ?? signature.node
    }
}

private enum Message {
    static func write(_ path: String, in context: String, prefix: String) -> String {
        "`\(path)` is set in \(context), outside the layout pass. "
            + "Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `\(prefix)…` helper."
    }

    static func helperCall(_ helper: String, from context: String) -> String {
        "`\(helper)` sets geometry and is called from \(context), outside the layout pass. "
            + "Call `setNeedsLayout()` instead, and `layoutIfNeeded()` to apply it now."
    }

    static func notPrivate(_ helper: String) -> String {
        "`\(helper)` must be `private` or `fileprivate` to count as a layout helper."
    }

    static func usedAsValue(_ helper: String) -> String {
        "`\(helper)` can be called from anywhere when it's used as a value or marked `@objc`. Call it only from layout methods."
    }
}

private final class WriteCollector: SyntaxVisitor {
    struct Write {
        let node: Syntax
        let target: AssignmentTarget
    }

    let index: SyntaxIndex
    var found: [Write] = []

    init(index: SyntaxIndex) {
        self.index = index
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if let target = index.assignmentTarget(of: node) {
            found.append(Write(node: Syntax(node), target: target))
        }
        return .visitChildren
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        if let target = index.assignmentTarget(of: node) {
            found.append(Write(node: Syntax(node), target: target))
        }
        return .visitChildren
    }
}
