import ArgumentParser
import Foundation
import LintableEngine

struct BaselineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "baseline",
        abstract: "Record the current violations, so `lint` reports only new ones."
    )

    @OptionGroup var configOptions: ConfigOptions
    @OptionGroup var selection: SelectionOptions

    @Option(help: "Where to write the baseline. Defaults to the config's `baseline`, or .lintable-baseline.json next to the config.")
    var output: String?

    func run() async throws {
        let registry = try configOptions.registry()
        let configuration = try configOptions.load(registry: registry)
        let files = try selection.files(configuration: configuration)
        let result = await Linter(configuration: configuration, registry: registry).lint(files: files)
        result.internalErrors.forEach(Console.error)
        if !result.internalErrors.isEmpty {
            throw ExitCode(3)
        }
        let url = output.map { URL(fileURLWithPath: $0) }
            ?? configuration.baselineURL
            ?? configuration.rootDirectory.appendingPathComponent(Configuration.defaultBaselineName)
        try Baseline(violations: result.violations).write(to: url)
        Console.output("Recorded \(result.violations.count) violations in \(url.path).")
    }
}
