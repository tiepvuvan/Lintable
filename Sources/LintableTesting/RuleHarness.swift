import Foundation
import LintableEngine
import LintableKit

struct RuleSubject {
    let pack: any RulePack.Type
    let id: RuleID
    let fileName: String
}

struct RuleHarness {
    struct Outcome {
        let lines: LineMap
        let ruleViolations: [ReportedViolation]
        let engineViolations: [ReportedViolation]
        let setupError: String?
    }

    static func run(_ subject: RuleSubject, options: String?, source: String, files: [String: String] = [:]) -> Outcome {
        let lines = LineMap(source: source)
        do {
            let registry = try RuleRegistry(packs: [subject.pack])
            let configuration = try Configuration.parse(
                yaml: configurationYAML(id: subject.id, options: options),
                rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
                registry: registry
            )
            let root = configuration.rootDirectory.path
            let linter = Linter(configuration: configuration, registry: registry) { url in
                files[FileDiscovery.relativePath(of: url.path, root: URL(fileURLWithPath: root))]
            }
            let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(subject.fileName).path
            let result = linter.lint(path: path, source: source)
            if let internalError = result.internalErrors.first {
                return Outcome(lines: lines, ruleViolations: [], engineViolations: [], setupError: internalError)
            }
            return Outcome(
                lines: lines,
                ruleViolations: result.violations.filter { $0.ruleID == subject.id },
                engineViolations: result.violations.filter { $0.ruleID != subject.id },
                setupError: nil
            )
        } catch {
            return Outcome(lines: lines, ruleViolations: [], engineViolations: [], setupError: String(describing: error))
        }
    }

    private static func configurationYAML(id: RuleID, options: String?) -> String {
        var lines = ["rules:", "  \(id.rawValue):"]
        if let options {
            lines += options.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + $0 }
        }
        return lines.joined(separator: "\n")
    }
}
