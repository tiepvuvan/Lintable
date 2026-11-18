import Foundation
import LintableEngine
import LintableKit
import Testing

@Suite struct LinterTests {
    @Test func reportsLinesColumnsAndText() throws {
        let violations = try lint("let a = 1\n    let b = forbidden\n")
        let violation = try #require(violations.first)
        #expect(violation.line == 2)
        #expect(violation.column == 13)
        #expect(violation.lineText == "let b = forbidden")
        #expect(violation.relativePath == "Sources/A.swift")
        #expect(violation.severity == .error)
    }

    @Test func lintsFilesInParallelAndSortsTheResult() async throws {
        let directory = try TemporaryDirectory()
        for index in 0 ..< 20 {
            try directory.write("Sources/File\(index).swift", "let a = forbidden\nlet b = forbidden\n")
        }
        let config = try configuration("rules:\n  forbidden_name:", root: directory.url)
        let files = FileDiscovery.files(in: [], configuration: config)
        let linter = try Linter(configuration: config, registry: registry())
        let first = await linter.lint(files: files)
        let second = await linter.lint(files: files)
        #expect(first.violations.count == 40)
        #expect(first.violations == first.violations.sorted())
        #expect(first.violations == second.violations)
        #expect(first.fileCount == 20)
        #expect(first.failed(strict: false))
    }

    @Test func aRuleReportingOutsideTheFileIsAnInternalError() async throws {
        let directory = try TemporaryDirectory()
        let file = try directory.write("A.swift", "let a = 1\n")
        let config = try configuration("rules:\n  out_of_bounds:", root: directory.url, packs: [BrokenRules.self])
        let result = await Linter(configuration: config, registry: try registry([BrokenRules.self])).lint(files: [file.path])
        #expect(result.violations.isEmpty)
        #expect(result.internalErrors.count == 1)
    }

    @Test func warningsFailOnlyWhenStrict() async throws {
        let directory = try TemporaryDirectory()
        let file = try directory.write("A.swift", "let a = forbidden\n")
        let config = try configuration("rules:\n  forbidden_name:\n    severity: warning", root: directory.url)
        let result = await Linter(configuration: config, registry: try registry()).lint(files: [file.path])
        #expect(result.warningCount == 1)
        #expect(!result.failed(strict: false))
        #expect(result.failed(strict: true))
    }
}

@Suite struct BaselineTests {
    private func violation(line: Int, text: String) -> ReportedViolation {
        ReportedViolation(
            ruleID: "forbidden_name",
            severity: .error,
            message: "`forbidden` is forbidden.",
            path: "/tmp/project/A.swift",
            relativePath: "A.swift",
            line: line,
            column: 9,
            lineText: text
        )
    }

    @Test func matchesAfterLinesMoveAndConsumesEachEntryOnce() {
        let baseline = Baseline(violations: [violation(line: 3, text: "let a = forbidden")])
        let moved = [violation(line: 10, text: "let a = forbidden"), violation(line: 11, text: "let a = forbidden")]
        #expect(baseline.filter(moved).map(\.line) == [11])
    }

    @Test func roundTripsThroughAFile() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent(".lintable-baseline.json")
        let baseline = Baseline(violations: [violation(line: 2, text: "b"), violation(line: 1, text: "a")])
        try baseline.write(to: url)
        let loaded = try Baseline.load(from: url)
        #expect(loaded == baseline)
        #expect(loaded.entries.map(\.line) == ["a", "b"])
    }
}

@Suite struct CacheTests {
    @Test func hitsUntilTheFileTheConfigOrTheRulesChange() throws {
        let directory = try TemporaryDirectory()
        let config = try configuration("rules:\n  forbidden_name:", root: directory.url)
        let otherConfig = try configuration("rules:\n  forbidden_name:\n    names: [x]", root: directory.url)
        let registry = try registry()
        let cache = Cache(directory: directory.url.appendingPathComponent("cache"), configuration: config, registry: registry)
        let violation = ReportedViolation(
            ruleID: "forbidden_name",
            severity: .error,
            message: "m",
            path: "/p/A.swift",
            relativePath: "A.swift",
            line: 1,
            column: 1,
            lineText: "x"
        )
        let stored = [violation]
        cache.store(stored, path: "/p/A.swift", source: "let a = 1")
        #expect(cache.load(path: "/p/A.swift", source: "let a = 1") == stored)
        #expect(cache.load(path: "/p/A.swift", source: "let a = 2") == nil)
        #expect(cache.load(path: "/p/B.swift", source: "let a = 1") == nil)
        let otherCache = Cache(directory: cache.directory, configuration: otherConfig, registry: registry)
        #expect(otherCache.load(path: "/p/A.swift", source: "let a = 1") == nil)
    }
}
