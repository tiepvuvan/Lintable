import LintableKit
import LintableTesting
import SwiftSyntax
import Testing

struct NoTodoRule: Rule {
    struct Options: RuleOptions {
        var word = "todo"
    }

    static let description = RuleDescription(
        id: "no_todo_call",
        name: "No todo call",
        summary: "Calls to a function named `todo`.",
        rationale: "A rule for testing the harness.",
        category: RuleCategory(id: "test", name: "Test"),
        triggeringExamples: [
            Example("""
            func run() {
                1️⃣todo()
            }
            """),
            Example("1️⃣later()", options: "word: later"),
        ],
        nonTriggeringExamples: [Example("func run() { done() }")]
    )

    let options: Options

    func check(_ file: LintFile) -> [Violation] {
        file.index.calls(named: options.word).map { Violation(at: $0.node, message: "Remove `\(options.word)()`.") }
    }
}

struct MisplacedExamplesRule: Rule {
    static let description = RuleDescription(
        id: "misplaced_examples",
        name: "Misplaced examples",
        summary: "A rule whose example markers are off.",
        rationale: "Checks that verifyExamples catches wrong examples.",
        category: RuleCategory(id: "test", name: "Test"),
        triggeringExamples: [Example("1️⃣let a = 1\ntodo()")],
        nonTriggeringExamples: [Example("todo()")]
    )

    init(options _: NoOptions) {}

    func check(_ file: LintFile) -> [Violation] {
        file.index.calls(named: "todo").map { Violation(at: $0.node, message: "Remove it.") }
    }
}

@Suite struct HarnessTests {
    @Test func passesWhenViolationsMatchTheMarkers() {
        assertLint(NoTodoRule.self, """
        1️⃣todo()
        func run() { 2️⃣todo() }
        """, messages: ["1️⃣": "Remove `todo()`."])
        assertLint(NoTodoRule.self, options: "word: fixme", "1️⃣fixme()\ntodo()")
    }

    @Test func reportsAMissingViolation() {
        withKnownIssue {
            assertLint(NoTodoRule.self, "1️⃣done()")
        }
    }

    @Test func reportsAnUnexpectedViolation() {
        withKnownIssue {
            assertLint(NoTodoRule.self, "todo()")
        }
    }

    @Test func reportsAWrongMessage() {
        withKnownIssue {
            assertLint(NoTodoRule.self, "1️⃣todo()", messages: ["1️⃣": "Something else."])
        }
    }

    @Test func reportsInvalidOptions() {
        withKnownIssue {
            assertLint(NoTodoRule.self, options: "colour: red", "todo()")
        }
    }

    @Test func verifiesAGoodRulesExamples() {
        verifyExamples(of: NoTodoRule.self)
    }

    @Test func catchesMisplacedExampleMarkers() {
        withKnownIssue {
            verifyExamples(of: MisplacedExamplesRule.self)
        }
    }
}
