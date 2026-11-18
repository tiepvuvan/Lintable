import ArgumentParser
import LintableEngine
import LintableKit

struct ExplainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Show a rule's documentation."
    )

    @Argument(help: "The rule's ID, for example layout_lifecycle.")
    var rule: String

    func run() async throws {
        let registry = try ConfigOptions().registry()
        let id = RuleID(rule)
        guard let description = registry.description(of: id) else {
            Console.error("No loaded rule is called `\(rule)`. Run `lintable rules` to list them.")
            throw ExitCode(2)
        }
        let defaults = (try? registry.defaultOptions(of: id)) ?? [:]
        Console.output(RuleDocumentation.page(for: description, defaults: defaults))
    }
}
