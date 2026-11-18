import ArgumentParser
import Foundation
import LintableEngine

struct LintCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Check Swift files with the rules the config enables."
    )

    @OptionGroup var configOptions: ConfigOptions
    @OptionGroup var selection: SelectionOptions
    @OptionGroup var cacheOptions: CacheOptions

    @Option(help: "How to print violations: \(Reporters.names.joined(separator: ", ")). Defaults to summary in a terminal and xcode otherwise.")
    var reporter: String?

    @Option(help: "A baseline file whose violations aren't reported. Defaults to the config's `baseline`.")
    var baseline: String?

    @Flag(name: .customLong("no-baseline"), help: "Report every violation, ignoring the baseline.")
    var noBaseline = false

    @Flag(help: "Fail on warnings too.")
    var strict = false

    func run() async throws {
        let registry = try configOptions.registry()
        let configuration = try configOptions.load(registry: registry)
        let renderer = try resolvedReporter()
        let files = try selection.files(configuration: configuration)
        let linter = Linter(
            configuration: configuration,
            registry: registry,
            cache: cacheOptions.cache(configuration: configuration, registry: registry)
        )
        let result = await linter.lint(files: files, baseline: try loadedBaseline(configuration))
        Console.output(renderer.render(result))
        result.internalErrors.forEach(Console.error)
        if !result.internalErrors.isEmpty {
            throw ExitCode(3)
        }
        if result.failed(strict: strict) {
            throw ExitCode(1)
        }
    }

    private func resolvedReporter() throws -> any Reporter {
        let name = reporter ?? (Console.isTerminal ? SummaryReporter.name : XcodeReporter.name)
        guard let resolved = Reporters.named(name) else {
            Console.error("Unknown reporter `\(name)`. Use one of: \(Reporters.names.joined(separator: ", ")).")
            throw ExitCode(2)
        }
        return resolved
    }

    private func loadedBaseline(_ configuration: Configuration) throws -> Baseline? {
        guard !noBaseline else { return nil }
        let url = baseline.map { URL(fileURLWithPath: $0) } ?? configuration.baselineURL
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            if let baseline {
                Console.error("No baseline at \(baseline).")
                throw ExitCode(2)
            }
            return nil
        }
        do {
            return try Baseline.load(from: url)
        } catch {
            Console.error("Can't read the baseline at \(url.path).")
            throw ExitCode(2)
        }
    }
}
