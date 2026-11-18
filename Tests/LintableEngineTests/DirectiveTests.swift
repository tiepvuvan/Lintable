import LintableEngine
import LintableKit
import Testing

@Suite struct DirectiveTests {
    private func ids(_ violations: [ReportedViolation]) -> [String] {
        violations.map { "\($0.line):\($0.ruleID)" }
    }

    @Test func disableNextSkipsBlankAndCommentLines() throws {
        let violations = try lint("""
        // lintable:disable:next forbidden_name - testing

        // a note
        let a = forbidden
        let b = forbidden
        """)
        #expect(ids(violations) == ["5:forbidden_name"])
    }

    @Test func disableThisAppliesToItsOwnLine() throws {
        let violations = try lint("""
        let a = forbidden // lintable:disable:this forbidden_name - testing
        let b = forbidden
        """)
        #expect(ids(violations) == ["2:forbidden_name"])
    }

    @Test func regionsRunUntilEnable() throws {
        let violations = try lint("""
        // lintable:disable forbidden_name - testing
        let a = forbidden
        let b = forbidden
        // lintable:enable forbidden_name
        let c = forbidden
        """)
        #expect(ids(violations) == ["5:forbidden_name"])
    }

    @Test func anOpenRegionRunsToTheEndOfTheFile() throws {
        let violations = try lint("""
        let a = forbidden
        // lintable:disable forbidden_name - testing
        let b = forbidden
        let c = forbidden
        """)
        #expect(ids(violations) == ["1:forbidden_name"])
    }

    @Test func severalRuleIDs() throws {
        let violations = try lint("""
        // lintable:disable:next forbidden_name, other_rule - testing
        let a = forbidden
        """)
        #expect(ids(violations) == ["1:unknown_rule"])
    }

    @Test func missingReasonIsReportedUnlessTurnedOff() throws {
        let source = """
        // lintable:disable:next forbidden_name
        let a = forbidden
        """
        #expect(ids(try lint(source)) == ["1:missing_reason"])
        #expect(ids(try lint(source, config: "require_reasons: false\nrules:\n  forbidden_name:")).isEmpty)
    }

    @Test func superfluousDirectivesAreReported() throws {
        let violations = try lint("""
        // lintable:disable:next forbidden_name - nothing to suppress
        let a = allowed
        """)
        #expect(ids(violations) == ["1:superfluous_directive"])
        #expect(violations.first?.severity == .warning)
    }

    @Test func directivesForDisabledRulesAreNotSuperfluous() throws {
        let violations = try lint("""
        // lintable:disable:next forbidden_name - testing
        let a = allowed
        """, config: "rules: {}")
        #expect(violations.isEmpty)
    }

    @Test func invalidDirectivesAreReported() throws {
        let violations = try lint("""
        // lintable:disabled:next forbidden_name - typo
        // lintable:disable:next - no rule
        let a = allowed
        """)
        #expect(ids(violations) == ["1:invalid_directive", "2:invalid_directive"])
    }

    @Test func engineSeveritiesComeFromTheConfig() throws {
        let violations = try lint("""
        // lintable:disable:next forbidden_name - nothing here
        let a = allowed
        """, config: "rules:\n  forbidden_name:\n  superfluous_directive:\n    severity: error")
        #expect(violations.first?.severity == .error)
    }

    @Test func ordinaryCommentsAreIgnored() throws {
        let violations = try lint("""
        // swiftlint:disable:next force_cast
        // lintable is great
        let a = allowed
        """)
        #expect(violations.isEmpty)
    }
}
