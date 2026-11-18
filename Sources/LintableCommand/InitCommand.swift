import ArgumentParser
import Foundation
import LintableEngine

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Write a starter .lintable.yml in the current directory."
    )

    @Flag(help: "Replace an existing config.")
    var force = false

    func run() async throws {
        let registry = try ConfigOptions().registry()
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(Configuration.fileName)
        if FileManager.default.fileExists(atPath: url.path), !force {
            Console.error("\(url.path) already exists. Use --force to replace it.")
            throw ExitCode(2)
        }
        var lines = [
            "included:",
            "  - .",
            "excluded:",
            "  - \"**/.build/**\"",
            "  - \"**/Tests/**\"",
            "require_reasons: true",
            "rules:",
        ]
        for description in registry.descriptions {
            lines.append("  \(description.id.rawValue):")
            lines.append("    severity: \(description.defaultSeverity.rawValue)")
        }
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url)
        Console.output("Wrote \(url.path) with \(registry.descriptions.count) rules enabled.")
    }
}
