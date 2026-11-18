import Foundation
import LintableEngine
import LintableKit

struct RuleHarness<R: Rule> {
    struct Outcome {
        let file: LintFile
        let ruleViolations: [ReportedViolation]
        let engineViolations: [ReportedViolation]
        let setupError: String?
    }

    static func run(options: String?, source: String) -> Outcome {
        let file = LintFile(path: "Example.swift", source: source)
        do {
            let registry = try RuleRegistry(packs: [SingleRulePack<R>.self])
            let configuration = try Configuration.parse(
                yaml: configurationYAML(options: options),
                rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
                registry: registry
            )
            let linter = Linter(configuration: configuration, registry: registry)
            let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Example.swift").path
            let violations = linter.lint(path: path, source: source).violations
            return Outcome(
                file: file,
                ruleViolations: violations.filter { $0.ruleID == R.description.id },
                engineViolations: violations.filter { $0.ruleID != R.description.id },
                setupError: nil
            )
        } catch {
            return Outcome(file: file, ruleViolations: [], engineViolations: [], setupError: String(describing: error))
        }
    }

    private static func configurationYAML(options: String?) -> String {
        var lines = ["rules:", "  \(R.description.id.rawValue):"]
        if let options {
            lines += options.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + $0 }
        }
        return lines.joined(separator: "\n")
    }
}
