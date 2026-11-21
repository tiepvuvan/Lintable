import AcmeRules
import LintableTesting
import Testing

@Suite("no_print_in_views")
struct NoPrintInViewsRuleTests {
    @Test("The examples report where their markers say")
    func examplesAreCorrect() {
        verifyExamples(of: NoPrintInViewsRule.self)
    }

    @Test("The message names the method and the view")
    func messageNamesTheMethodAndTheView() {
        assertLint(NoPrintInViewsRule.self, """
        final class ChartView: UIView {
            override func draw(_ rect: CGRect) {
                1️⃣print(rect)
            }
        }
        """, messages: [
            "1️⃣": "`print` in `draw(_:)` of `ChartView` writes to the console every time the view runs it, "
                + "in release builds too. Log through the app's logger instead.",
        ])
    }

    @Test("A view class from another file counts once it's listed in view_classes")
    func viewClassesOption() {
        assertLint(NoPrintInViewsRule.self, options: "view_classes: [UIView, CardView]", """
        final class StatsCard: CardView {
            init() {
                super.init(frame: .zero)
                1️⃣print("created")
            }
        }

        final class StatsFormatter {
            func format() {
                print("not a view")
            }
        }
        """)
    }

    @Test("A disable directive with a reason silences the rule")
    func directiveSilencesTheRule() {
        assertLint(NoPrintInViewsRule.self, """
        final class ChartView: UIView {
            func dump() {
                // lintable:disable:next no_print_in_views - called only from the debug menu
                print(subviews)
            }
        }
        """)
    }
}
