import ArgumentParser
import Foundation
import LintableEngine
import LintableKit

struct RulesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "List the loaded rules."
    )

    @OptionGroup var configOptions: ConfigOptions

    func run() async throws {
        let registry = try configOptions.registry()
        let enabled: Set<RuleID>? = configOptions.configurationURL().flatMap { url in
            (try? Configuration.load(from: url, registry: registry)).map(\.enabledRuleIDs)
        }
        let descriptions = registry.descriptions
        let width = max(4, descriptions.map(\.id.rawValue.count).max() ?? 0)
        var lines = ["Rule".padded(width) + "  Category".padded(30) + "  Default  Enabled"]
        for description in descriptions {
            let state = enabled.map { $0.contains(description.id) ? "yes" : "no" } ?? "-"
            lines.append(
                description.id.rawValue.padded(width)
                    + "  " + description.category.name.padded(28)
                    + "  " + description.defaultSeverity.rawValue.padded(7)
                    + "  " + state
            )
        }
        Console.output(lines.joined(separator: "\n"))
    }
}

extension String {
    func padded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
