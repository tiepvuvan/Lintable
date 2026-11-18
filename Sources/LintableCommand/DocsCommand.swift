import ArgumentParser
import Foundation
import LintableEngine

struct DocsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docs",
        abstract: "Write a Markdown page for every loaded rule, and an index."
    )

    @Option(help: "The folder to write to.")
    var output = "docs/rules"

    func run() async throws {
        let registry = try ConfigOptions().registry()
        let folder = URL(fileURLWithPath: output, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptions = registry.descriptions + EngineRules.descriptions
        for description in descriptions {
            let defaults = (try? registry.defaultOptions(of: description.id)) ?? [:]
            let page = RuleDocumentation.page(for: description, defaults: defaults)
            try Data(page.utf8).write(to: folder.appendingPathComponent("\(description.id.rawValue).md"))
        }
        try Data(RuleDocumentation.index(for: descriptions).utf8).write(to: folder.appendingPathComponent("README.md"))
        Console.output("Wrote \(descriptions.count) rule pages to \(folder.path).")
    }
}
