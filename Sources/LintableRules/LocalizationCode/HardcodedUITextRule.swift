import LintableKit
import SwiftSyntax

public struct HardcodedUITextRule: Rule {
    public struct Options: RuleOptions {
        public var properties = [
            "text", "title", "subtitle", "body", "placeholder", "prompt", "secondaryText",
            "accessibilityLabel", "accessibilityHint", "accessibilityValue",
        ]
        public var calls = [
            "UIAlertController(title:)", "UIAlertController(message:)", "UIAlertAction(title:)",
            "UIBarButtonItem(title:)", "UIAction(title:)", "UIMenu(title:)", "UIContextualAction(title:)",
            "setTitle(_:)", "NSAttributedString(string:)",
        ]
        public var checkVerbatimText = true

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ file: LintFile) -> [Violation] {
        let visitor = HardcodedUITextVisitor(options: options, index: file.index)
        visitor.walk(file.tree)
        return visitor.violations
    }
}

private struct CallSink: Hashable {
    let name: String
    let label: String?

    init?(_ text: String) {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(":)") else { return nil }
        name = String(text[..<open])
        let label = String(text[text.index(after: open) ..< text.index(text.endIndex, offsetBy: -2)])
        self.label = label == "_" ? nil : label
    }
}

private final class HardcodedUITextVisitor: SyntaxVisitor {
    let properties: Set<String>
    let sinks: Set<CallSink>
    let checkVerbatimText: Bool
    let index: SyntaxIndex
    var violations: [Violation] = []

    init(options: HardcodedUITextRule.Options, index: SyntaxIndex) {
        self.index = index
        properties = Set(options.properties)
        sinks = Set(options.calls.compactMap(CallSink.init))
        checkVerbatimText = options.checkVerbatimText
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.is(AssignmentExprSyntax.self) {
            checkAssignment(left: node.leftOperand, right: node.rightOperand)
        }
        return .visitChildren
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        if elements.count == 3, elements[1].is(AssignmentExprSyntax.self) {
            checkAssignment(left: elements[0], right: elements[2])
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let name = LocalizationSyntax.calleeName(node) else { return .visitChildren }
        if checkVerbatimText, name == "Text", let first = node.arguments.first, first.label?.text == "verbatim",
           let literal = first.expression.as(StringLiteralExprSyntax.self)
        {
            let text = LocalizationSyntax.text(of: literal)
            if text.trimmingCharacters(in: .whitespaces).contains(" "), LocalizationSyntax.looksLikeUIText(text) {
                report(literal, text: text, place: "`Text(verbatim:)`")
            }
        }
        for (index, argument) in node.arguments.enumerated() {
            let label = argument.label?.text
            let isSink = sinks.contains(CallSink(name: name, label: label))
                || (index == 0 && label == nil && sinks.contains(CallSink(name: name, label: nil)))
            guard isSink, let literal = argument.expression.as(StringLiteralExprSyntax.self) else { continue }
            let text = LocalizationSyntax.text(of: literal)
            if LocalizationSyntax.looksLikeUIText(text) {
                report(literal, text: text, place: label.map { "`\(name)(\($0):)`" } ?? "`\(name)`")
            }
        }
        return .visitChildren
    }

    private func checkAssignment(left: ExprSyntax, right: ExprSyntax) {
        guard let member = left.as(MemberAccessExprSyntax.self), properties.contains(member.declName.baseName.text),
              let literal = right.as(StringLiteralExprSyntax.self)
        else {
            return
        }
        let text = LocalizationSyntax.text(of: literal)
        if LocalizationSyntax.looksLikeUIText(text) {
            report(literal, text: text, place: "`\(member.declName.baseName.text)`")
        }
    }

    private func report(_ literal: StringLiteralExprSyntax, text: String, place: String) {
        guard !LocalizationSyntax.isInDebugOrPreviewCode(literal, index: index) else { return }
        let message = "\(LocalizationSyntax.quoted(text)) reaches \(place) without being localized. "
            + "Use `String(localized:comment:)` so translators see it."
        violations.append(Violation(at: literal, message: message))
    }
}

private extension CallSink {
    init(name: String, label: String?) {
        self.name = name
        self.label = label
    }
}

public extension HardcodedUITextRule {
    static let description = RuleDescription(
        id: "hardcoded_ui_text",
        name: "Hard-coded UI text",
        summary: "A string literal reaches UI text without being localized.",
        rationale: """
        A literal assigned to a label's `text`, a controller's `title`, an alert's title or an accessibility label shows \
        English to everyone, and no String Catalog lists it, so no translation check can see it. The rule reports \
        literals that look like text, with letters and a space or a capital letter, in those places, and in \
        `Text(verbatim:)`. Code inside `#if DEBUG`, `#Preview` and `PreviewProvider` types is skipped. For text that \
        stays English on purpose, add `// lintable:disable:next hardcoded_ui_text - <reason>`.
        """,
        category: .localization,
        defaultSeverity: .warning,
        optionDescriptions: [
            "properties": "Properties whose assignment shows text, on any type.",
            "calls": "Calls whose argument shows text, written `Name(label:)`, or `name(_:)` for the first unlabeled argument.",
            "check_verbatim_text": "Also report `Text(verbatim:)` with text that has several words.",
        ],
        triggeringExamples: [
            Example("""
            func configure() {
                picker.title = 1️⃣"Select Time"
                let alert = UIAlertController(title: 2️⃣"Oops!", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: 3️⃣"OK", style: .default))
                button.setTitle(4️⃣"Done", for: .normal)
            }
            """),
            Example("""
            var body: some View {
                Text(verbatim: 1️⃣"Your day, beautifully organized")
            }
            """),
        ],
        nonTriggeringExamples: [
            Example("""
            func configure() {
                picker.title = String(localized: "Select Time", comment: "Title of the time picker.")
                cell.accessibilityIdentifier = "habitCell"
                label.text = "%"
                Text(verbatim: "•")
                #if DEBUG
                    debugLabel.text = "Debug build"
                #endif
            }
            """),
        ],
        howToFix: """
        Wrap the text in `String(localized: "…", comment: "…")`, or use the SwiftUI initializer that takes a \
        `LocalizedStringKey`, such as `Text("…")`.
        """
    )
}
