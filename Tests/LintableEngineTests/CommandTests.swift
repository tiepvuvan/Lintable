import ArgumentParser
import Foundation
@testable import LintableCommand
import LintableEngine
import LintableKit
import Testing

@Suite(.serialized) struct CommandTests {
    private func run(_ arguments: [String], packs: [any RulePack.Type] = [TestRules.self]) async -> Int32 {
        LoadedRulePacks.packs = packs
        do {
            var command = try RootCommand.parseAsRoot(arguments)
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            return 0
        } catch let exit as ExitCode {
            return exit.rawValue
        } catch {
            return -1
        }
    }

    private func project(_ source: String, config: String = "rules:\n  forbidden_name:") throws -> TemporaryDirectory {
        let directory = try TemporaryDirectory()
        try directory.write(".lintable.yml", config)
        try directory.write("Sources/A.swift", source)
        return directory
    }

    private func arguments(_ command: String, _ directory: TemporaryDirectory, _ extra: [String] = []) -> [String] {
        [command, "--config", directory.url.appendingPathComponent(".lintable.yml").path] + extra
    }

    @Test func lintExitsWithOneOnErrorsAndZeroWhenClean() async throws {
        let failing = try project("let a = forbidden\n")
        #expect(await run(arguments("lint", failing, ["--no-cache", "--reporter", "xcode", failing.url.path])) == 1)
        let clean = try project("let a = allowed\n")
        #expect(await run(arguments("lint", clean, ["--no-cache", "--reporter", "xcode", clean.url.path])) == 0)
    }

    @Test func lintWritesTheReleaseGate() async throws {
        let directory = try TemporaryDirectory()
        try directory.write(".lintable.yml", "release_condition: \"!DEBUG\"\nrules:\n  forbidden_key:\n    release_severity: error")
        try directory.write("Resources/Localizable.xcstrings", forbiddenKeyCatalog)
        let gate = directory.url.appendingPathComponent("Output/LintableReleaseGate.swift")
        let extra = ["--no-cache", "--reporter", "xcode", "--release-gate", gate.path, directory.url.path]
        #expect(await run(arguments("lint", directory, extra), packs: [CatalogTestRules.self]) == 0)
        let source = String(decoding: try Data(contentsOf: gate), as: UTF8.self)
        #expect(source.hasPrefix("#if !DEBUG\n#error(\"1 forbidden_key warning stops release builds."))
    }

    @Test func strictFailsOnWarnings() async throws {
        let directory = try project("let a = forbidden\n", config: "rules:\n  forbidden_name:\n    severity: warning")
        let base = arguments("lint", directory, ["--no-cache", "--reporter", "xcode", directory.url.path])
        #expect(await run(base) == 0)
        #expect(await run(base + ["--strict"]) == 1)
    }

    @Test func configAndUsageErrorsExitWithTwo() async throws {
        let directory = try project("let a = 1\n", config: "rules:\n  nope:")
        #expect(await run(arguments("lint", directory, ["--no-cache"])) == 2)
        let valid = try project("let a = 1\n")
        #expect(await run(arguments("lint", valid, ["--reporter", "html"])) == 2)
        #expect(await run(["lint", "--config", valid.url.appendingPathComponent("missing.yml").path]) == 2)
    }

    @Test func internalErrorsExitWithThree() async throws {
        let directory = try project("let a = 1\n", config: "rules:\n  out_of_bounds:")
        #expect(await run(arguments("lint", directory, ["--no-cache", directory.url.path]), packs: [BrokenRules.self]) == 3)
    }

    @Test func baselineSilencesRecordedViolations() async throws {
        let directory = try project("let a = forbidden\n", config: "baseline: .lintable-baseline.json\nrules:\n  forbidden_name:")
        #expect(await run(arguments("baseline", directory, [directory.url.path])) == 0)
        let baseline = directory.url.appendingPathComponent(".lintable-baseline.json")
        #expect(FileManager.default.fileExists(atPath: baseline.path))
        #expect(await run(arguments("lint", directory, ["--no-cache", "--reporter", "xcode", directory.url.path])) == 0)
        #expect(await run(arguments("lint", directory, ["--no-cache", "--no-baseline", "--reporter", "xcode", directory.url.path])) == 1)
        try directory.write("Sources/B.swift", "let b = forbidden\n")
        #expect(await run(arguments("lint", directory, ["--no-cache", "--reporter", "xcode", directory.url.path])) == 1)
    }

    @Test func filesFromListsTheFilesToCheck() async throws {
        let directory = try project("let a = allowed\n")
        let failing = try directory.write("Sources/B.swift", "let b = forbidden\n")
        let list = try directory.write("files.txt", "\(failing.path)\n")
        #expect(await run(arguments("lint", directory, ["--no-cache", "--reporter", "xcode", "--files-from", list.path])) == 1)
    }

    @Test func theCacheGivesTheSameResult() async throws {
        let directory = try project("let a = forbidden\n")
        let cache = directory.url.appendingPathComponent("cache").path
        let base = arguments("lint", directory, ["--cache-path", cache, "--reporter", "xcode", directory.url.path])
        #expect(await run(base) == 1)
        #expect(FileManager.default.fileExists(atPath: cache))
        #expect(await run(base) == 1)
    }

    @Test func docsWritesAPagePerRuleAndAnIndex() async throws {
        let directory = try TemporaryDirectory()
        let output = directory.url.appendingPathComponent("docs").path
        #expect(await run(["docs", "--output", output]) == 0)
        let pages = try FileManager.default.contentsOfDirectory(atPath: output).sorted()
        #expect(pages.contains("forbidden_name.md"))
        #expect(pages.contains("superfluous_directive.md"))
        #expect(pages.contains("README.md"))
    }

    @Test func explainKnowsLoadedAndEngineRules() async {
        #expect(await run(["explain", "forbidden_name"]) == 0)
        #expect(await run(["explain", "missing_reason"]) == 0)
        #expect(await run(["explain", "nope"]) == 2)
    }

    @Test func initWritesAConfigListingEveryRule() async throws {
        let directory = try TemporaryDirectory()
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(directory.url.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        #expect(await run(["init"]) == 0)
        let config = try String(contentsOf: directory.url.appendingPathComponent(".lintable.yml"), encoding: .utf8)
        #expect(config.contains("  forbidden_name:\n    severity: error"))
        #expect(await run(["init"]) == 2)
        #expect(await run(["init", "--force"]) == 0)
        let parsed = try Configuration.parse(yaml: config, rootDirectory: directory.url, registry: registry())
        #expect(parsed.rules.map(\.id) == ["forbidden_name"])
    }
}
