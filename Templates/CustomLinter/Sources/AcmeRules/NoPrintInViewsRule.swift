import LintableKit
import SwiftSyntax

public struct NoPrintInViewsRule: Rule {
    public struct Options: RuleOptions {
        public var viewClasses: [String] = ["UIView", "NSView"]

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ file: LintFile) -> [Violation] {
        let viewClasses = Set(options.viewClasses)
        return file.index.calls(named: "print").compactMap { call in
            guard call.receiver == .implicit,
                  let type = file.index.types(of: call.node).first,
                  viewClasses.contains(type.name) || file.index.inheritsFrom(type, anyOf: viewClasses)
            else {
                return nil
            }
            let place = file.index.scopes(of: call.node).first { !$0.isClosure }?.name ?? "a closure"
            let message = "`print` in \(place) of `\(type.name)` writes to the console every time the view runs it, "
                + "in release builds too. Log through the app's logger instead."
            return Violation(at: call.node, message: message)
        }
    }
}

public extension NoPrintInViewsRule {
    static let description = RuleDescription(
        id: "no_print_in_views",
        name: "No print in views",
        summary: "A view calls `print`.",
        rationale: """
        Views lay out, draw and handle events many times a second, so a `print` left in a view floods the console, \
        slows scrolling and ships in release builds. The rule reports `print(…)` anywhere inside a class that \
        inherits from one of `view_classes`, directly or through classes declared in the same file, and inside \
        extensions of those classes. It looks at one file at a time: list your own base view classes in \
        `view_classes` when they're declared in another file.
        """,
        category: .acme,
        defaultSeverity: .warning,
        optionDescriptions: [
            "view_classes": "Classes whose subclasses are views. Add your own base classes declared in other files.",
        ],
        triggeringExamples: [
            Example("""
            final class ChartView: UIView {
                override func layoutSubviews() {
                    super.layoutSubviews()
                    1️⃣print("layout", bounds)
                }
            }
            """),
            Example("""
            class BadgeBaseView: UIView {}

            final class BadgeView: BadgeBaseView {
                var count = 0 {
                    didSet {
                        1️⃣print(count)
                    }
                }
            }
            """),
            Example("""
            final class ChartView: UIView {}

            extension ChartView {
                func reload() {
                    DispatchQueue.main.async {
                        1️⃣print("reload")
                    }
                }
            }
            """),
            Example("""
            final class StatsCard: CardView {
                func update() {
                    1️⃣print("update")
                }
            }
            """, options: "view_classes: [CardView]"),
        ],
        nonTriggeringExamples: [
            Example("""
            final class ChartViewModel {
                func reload() {
                    print("reload")
                }
            }
            """),
            Example("""
            final class ChartView: UIView {
                func reload() {
                    logger.debug("reload")
                }
            }
            """),
            Example("""
            final class ChartView: UIView {
                struct Layout {
                    func describe() {
                        print("A nested type isn't a view.")
                    }
                }
            }
            """),
            Example("""
            final class ChartView: UIView {
                func render(with printer: Printer) {
                    printer.print(bounds)
                }
            }
            """),
        ],
        howToFix: """
        Log through the app's logger, which can be filtered and turned off, or delete the call once you're done \
        debugging.
        """,
        documentationURL: "https://example.com/acme-lint/rules/no_print_in_views"
    )
}
