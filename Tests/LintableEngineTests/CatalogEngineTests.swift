import Foundation
import LintableEngine
import LintableKit
import Testing

@Suite struct CatalogEngineTests {
    private func linter(_ yaml: String, root: URL, cache: Cache? = nil) throws -> Linter {
        let config = try configuration(yaml, root: root, packs: [CatalogTestRules.self])
        return try Linter(configuration: config, registry: registry([CatalogTestRules.self]), cache: cache)
    }

    @Test func discoversStringCatalogs() throws {
        let directory = try TemporaryDirectory()
        try directory.write("Sources/A.swift", "")
        try directory.write("Sources/Resources/Localizable.xcstrings", forbiddenKeyCatalog)
        try directory.write("Sources/Resources/Notes.json", "{}")
        let config = try configuration("included: [Sources]", root: directory.url, packs: [CatalogTestRules.self])
        let files = FileDiscovery.files(in: [], configuration: config).map { FileDiscovery.relativePath(of: $0, root: directory.url) }
        #expect(files == ["Sources/A.swift", "Sources/Resources/Localizable.xcstrings"])
        #expect(FileDiscovery.filter(["/tmp/a.xcstrings", "/tmp/b.json"], configuration: config) == ["/tmp/a.xcstrings"])
    }

    @Test func runsCatalogRulesOnCatalogsAndSwiftRulesOnSwiftFiles() async throws {
        let directory = try TemporaryDirectory()
        let swift = try directory.write("A.swift", "let a = forbidden\n")
        let strings = try directory.write("Localizable.xcstrings", forbiddenKeyCatalog)
        let result = try await linter("rules:\n  forbidden_name:\n  forbidden_key:", root: directory.url).lint(files: [swift.path, strings.path])
        #expect(result.violations.map(\.ruleID) == ["forbidden_name", "forbidden_key"])
        let violation = try #require(result.violations.last)
        #expect((violation.line, violation.column) == (5, 5))
        #expect(violation.lineText == "\"forbidden\" : { }")
        #expect(violation.relativePath == "Localizable.xcstrings")
        #expect(violation.severity == .warning)
    }

    @Test func catalogRulesReadTheCatalogsTheyReference() async throws {
        let directory = try TemporaryDirectory()
        let host = try directory.write("App/Localizable.xcstrings", forbiddenKeyCatalog)
        try directory.write("Kit/Localizable.xcstrings", #"{ "strings" : { "allowed" : { }, "kit only" : { } } }"#)
        let yaml = "rules:\n  shared_keys:\n    source: Kit/Localizable.xcstrings"
        let cache = try Cache(directory: directory.url.appendingPathComponent("cache"), configuration: configuration(yaml, root: directory.url, packs: [CatalogTestRules.self]), registry: registry([CatalogTestRules.self]))
        let first = try await linter(yaml, root: directory.url, cache: cache).lint(files: [host.path])
        #expect(first.violations.map(\.message) == ["Missing kit only from App/Localizable.xcstrings."])
        try directory.write("Kit/Localizable.xcstrings", #"{ "strings" : { "allowed" : { }, "forbidden" : { } } }"#)
        let second = try await linter(yaml, root: directory.url, cache: cache).lint(files: [host.path])
        #expect(second.violations.isEmpty)
        try FileManager.default.removeItem(at: directory.url.appendingPathComponent("Kit/Localizable.xcstrings"))
        let third = try await linter(yaml, root: directory.url, cache: cache).lint(files: [host.path])
        #expect(third.violations.map(\.message) == ["Missing (unreadable) from App/Localizable.xcstrings."])
    }

    @Test func leavesCatalogsUnreadWithoutCatalogRules() async throws {
        let directory = try TemporaryDirectory()
        let strings = try directory.write("Localizable.xcstrings", "not json")
        let result = try await linter("rules:\n  forbidden_name:", root: directory.url).lint(files: [strings.path])
        #expect(result.violations.isEmpty)
        #expect(result.internalErrors.isEmpty)
        #expect(result.fileCount == 1)
    }

    @Test func aBrokenCatalogIsAnInternalError() async throws {
        let directory = try TemporaryDirectory()
        let strings = try directory.write("Localizable.xcstrings", "{\n  \"strings\" :\n}")
        let result = try await linter("rules:\n  forbidden_key:", root: directory.url).lint(files: [strings.path])
        #expect(result.internalErrors == ["Localizable.xcstrings isn't a valid String Catalog. Line 3, column 1: Expected a value."])
    }

    @Test func aHigherReleaseSeverityMarksReleaseBlockers() async throws {
        let directory = try TemporaryDirectory()
        let strings = try directory.write("Localizable.xcstrings", forbiddenKeyCatalog)
        let yaml = "release_condition: \"!DEBUG && !TESTFLIGHT\"\nrules:\n  forbidden_key:\n    release_severity: error"
        let linter = try linter(yaml, root: directory.url)
        #expect(linter.configuration.releaseCondition == "!DEBUG && !TESTFLIGHT")
        #expect(linter.configuration.rules.first?.releaseSeverity == .error)
        let result = await linter.lint(files: [strings.path])
        #expect(result.releaseBlockers.count == 1)
        #expect(!result.failed(strict: false))
        let gate = ReleaseGate.source(blocking: result.releaseBlockers, condition: linter.configuration.releaseCondition)
        #expect(gate == """
        #if !DEBUG && !TESTFLIGHT
        #error("1 forbidden_key warning stops release builds. The first is Localizable.xcstrings:5: The key is forbidden.")
        #endif

        """)
        #expect(ReleaseGate.source(blocking: [], condition: "!DEBUG").isEmpty)
        #expect(ReleaseGate.source(blocking: result.releaseBlockers, condition: nil).isEmpty)
    }

    @Test func aReleaseSeverityNoHigherThanTheSeverityBlocksNothing() async throws {
        let directory = try TemporaryDirectory()
        let strings = try directory.write("Localizable.xcstrings", forbiddenKeyCatalog)
        let yaml = "release_condition: \"!DEBUG\"\nrules:\n  forbidden_key:\n    severity: error\n    release_severity: warning"
        let result = try await linter(yaml, root: directory.url).lint(files: [strings.path])
        #expect(result.releaseBlockers.isEmpty)
        #expect(result.failed(strict: false))
    }

    @Test(arguments: [
        #"release_condition: "DEBUG\n#error(\"x\")""#,
        #"release_condition: """#,
        #"release_condition: "a; b""#,
        "release_condition: [DEBUG]",
    ])
    func rejectsAReleaseConditionThatIsntACompilationCondition(yaml: String) {
        #expect(throws: ConfigurationError.invalidValue(key: "release_condition", expected: "a compilation condition such as `!DEBUG`")) {
            try configuration(yaml, packs: [CatalogTestRules.self])
        }
    }

    @Test func checksReleaseSeveritiesLikeSeverities() {
        #expect(throws: ConfigurationError.invalidSeverity(rule: "forbidden_key", value: "fatal")) {
            try configuration("rules:\n  forbidden_key:\n    release_severity: fatal", packs: [CatalogTestRules.self])
        }
        #expect(throws: ConfigurationError.unknownOptions(rule: EngineRules.missingReason, keys: ["release_severity"])) {
            try configuration("rules:\n  missing_reason:\n    release_severity: error", packs: [CatalogTestRules.self])
        }
    }

    @Test func escapesTheGateMessage() {
        let violation = ReportedViolation(
            ruleID: "forbidden_key",
            severity: .warning,
            message: "Say \"hi\" \\ then\nleave.",
            path: "/tmp/A.xcstrings",
            relativePath: "A.xcstrings",
            line: 2,
            column: 3,
            lineText: ""
        )
        let gate = ReleaseGate.source(blocking: [violation, violation], condition: "!DEBUG")
        #expect(gate.contains(#"#error("2 forbidden_key warnings stop release builds. The first is A.xcstrings:2: Say \"hi\" \\ then leave.")"#))
    }

    @Test func writesTheGateOnlyWhenItChanges() throws {
        let directory = try TemporaryDirectory()
        let path = directory.url.appendingPathComponent("Output/\(ReleaseGate.fileName)").path
        let past = Date(timeIntervalSince1970: 1_000_000_000)
        try ReleaseGate.write("#if X\n#endif\n", to: path)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: path)
        try ReleaseGate.write("#if X\n#endif\n", to: path)
        #expect(try modificationDate(of: path) == past)
        try ReleaseGate.write("", to: path)
        #expect(try modificationDate(of: path) != past)
        #expect(FileManager.default.contents(atPath: path) == Data())
    }

    private func modificationDate(of path: String) throws -> Date? {
        try FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
}
