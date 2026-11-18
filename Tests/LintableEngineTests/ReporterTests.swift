import Foundation
import LintableEngine
import LintableKit
import Testing

@Suite struct ReporterTests {
    private var result: LintResult {
        LintResult(
            violations: [
                ReportedViolation(
                    ruleID: "forbidden_name",
                    severity: .error,
                    message: "`forbidden` is forbidden.",
                    path: "/tmp/project/Sources/A.swift",
                    relativePath: "Sources/A.swift",
                    line: 2,
                    column: 9,
                    lineText: "let a = forbidden"
                ),
                ReportedViolation(
                    ruleID: "superfluous_directive",
                    severity: .warning,
                    message: "This directive suppresses no violation, 100%.",
                    path: "/tmp/project/Sources/B.swift",
                    relativePath: "Sources/B.swift",
                    line: 1,
                    column: 1,
                    lineText: "// lintable:disable:next forbidden_name - x"
                ),
            ],
            fileCount: 3,
            rules: [ForbiddenNameRule.description] + EngineRules.descriptions,
            internalErrors: []
        )
    }

    @Test func xcode() {
        #expect(XcodeReporter().render(result) == """
        /tmp/project/Sources/A.swift:2:9: error: `forbidden` is forbidden. (forbidden_name)
        /tmp/project/Sources/B.swift:1:1: warning: This directive suppresses no violation, 100%. (superfluous_directive)
        """)
    }

    @Test func github() {
        #expect(GitHubReporter().render(result) == """
        ::error file=Sources/A.swift,line=2,col=9,title=forbidden_name::`forbidden` is forbidden.
        ::warning file=Sources/B.swift,line=1,col=1,title=superfluous_directive::This directive suppresses no violation, 100%25.
        """)
    }

    @Test func summary() {
        #expect(SummaryReporter().render(result) == """
        Sources/A.swift
          2:9      error   `forbidden` is forbidden.  forbidden_name

        Sources/B.swift
          1:1      warning This directive suppresses no violation, 100%.  superfluous_directive

        1 error and 1 warning in 2 of 3 files.
          forbidden_name: 1
          superfluous_directive: 1
        """)
    }

    @Test func summaryWithNothingToReport() {
        let clean = LintResult(violations: [], fileCount: 1, rules: [], internalErrors: [])
        #expect(SummaryReporter().render(clean) == "No violations in 1 file.")
        #expect(XcodeReporter().render(clean).isEmpty)
    }

    @Test func json() throws {
        let data = Data(JSONReporter().render(result).utf8)
        let items = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(items.count == 2)
        #expect(items[0]["rule"] as? String == "forbidden_name")
        #expect(items[0]["path"] as? String == "Sources/A.swift")
        #expect(items[0]["line"] as? Int == 2)
        #expect(items[0]["documentation"] as? String == ForbiddenNameRule.description.documentationURL)
    }

    @Test func sarif() throws {
        let data = Data(SARIFReporter().render(result).utf8)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(document["version"] as? String == "2.1.0")
        let run = try #require((document["runs"] as? [[String: Any]])?.first)
        let driver = try #require((run["tool"] as? [String: Any])?["driver"] as? [String: Any])
        #expect((driver["rules"] as? [[String: Any]])?.map { $0["id"] as? String } == ["forbidden_name"] + EngineRules.descriptions.map(\.id.rawValue))
        let results = try #require(run["results"] as? [[String: Any]])
        #expect(results.map { $0["level"] as? String } == ["error", "warning"])
    }

    @Test func everyReporterHasAUniqueName() {
        #expect(Set(Reporters.names).count == Reporters.all.count)
        #expect(Reporters.named("sarif") is SARIFReporter)
        #expect(Reporters.named("html") == nil)
    }
}

@Suite struct DocumentationTests {
    @Test func pageListsOptionsExamplesAndRationale() throws {
        let page = RuleDocumentation.page(
            for: ForbiddenNameRule.description,
            defaults: try registry().defaultOptions(of: "forbidden_name")
        )
        #expect(page.hasPrefix("# `forbidden_name`\n"))
        #expect(page.contains("| `names` | `forbidden` | Identifiers to report. |"))
        #expect(page.contains("| `report_calls` | `true` | Also report calls. |"))
        #expect(page.contains("let value = ↓forbidden"))
        #expect(page.contains("## Rationale"))
    }

    @Test func indexLinksEveryRule() {
        let index = RuleDocumentation.index(for: [ForbiddenNameRule.description])
        #expect(index.contains("[`forbidden_name`](forbidden_name.md)"))
    }
}
