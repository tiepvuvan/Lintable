import Foundation
import LintableKit

public struct LintResult: Sendable {
    public let violations: [ReportedViolation]
    public let fileCount: Int
    public let rules: [RuleDescription]
    public let internalErrors: [String]

    public init(violations: [ReportedViolation], fileCount: Int, rules: [RuleDescription], internalErrors: [String]) {
        self.violations = violations
        self.fileCount = fileCount
        self.rules = rules
        self.internalErrors = internalErrors
    }

    public var errorCount: Int {
        violations.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        violations.filter { $0.severity == .warning }.count
    }

    public func failed(strict: Bool) -> Bool {
        errorCount > 0 || (strict && warningCount > 0)
    }
}

public struct Linter: Sendable {
    public let configuration: Configuration
    public let registry: RuleRegistry
    public let cache: Cache?

    public init(configuration: Configuration, registry: RuleRegistry, cache: Cache? = nil) {
        self.configuration = configuration
        self.registry = registry
        self.cache = cache
    }

    public func lint(files: [String], baseline: Baseline? = nil) async -> LintResult {
        let concurrency = max(1, ProcessInfo.processInfo.activeProcessorCount)
        var results: [FileResult] = []
        await withTaskGroup(of: FileResult.self) { group in
            var pending = files[...]
            for _ in 0 ..< concurrency {
                guard let path = pending.popFirst() else { break }
                group.addTask { lintFile(atPath: path) }
            }
            for await result in group {
                results.append(result)
                if let path = pending.popFirst() {
                    group.addTask { lintFile(atPath: path) }
                }
            }
        }
        var violations = results.flatMap(\.violations).sorted()
        if let baseline {
            violations = baseline.filter(violations)
        }
        let descriptions = configuration.rules.map(\.description) + EngineRules.descriptions
        return LintResult(
            violations: violations,
            fileCount: files.count,
            rules: descriptions.sorted { $0.id < $1.id },
            internalErrors: results.flatMap(\.internalErrors).sorted()
        )
    }

    public func lint(path: String, source: String) -> (violations: [ReportedViolation], internalErrors: [String]) {
        let file = LintFile(path: path, source: source)
        let relativePath = FileDiscovery.relativePath(of: path, root: configuration.rootDirectory)
        var violations: [ReportedViolation] = []
        var internalErrors: [String] = []
        let length = source.utf8.count
        for rule in configuration.rules {
            for violation in rule.check(file) {
                guard violation.position.utf8Offset >= 0, violation.position.utf8Offset <= length else {
                    internalErrors.append("Rule `\(rule.id)` reported a position outside \(relativePath).")
                    continue
                }
                let location = file.location(of: violation.position)
                violations.append(ReportedViolation(
                    ruleID: rule.id,
                    severity: rule.severity,
                    message: violation.message,
                    path: path,
                    relativePath: relativePath,
                    line: location.line,
                    column: location.column,
                    lineText: file.lineText(location.line),
                    notes: violation.notes.map { note in
                        let noteLocation = file.location(of: note.position)
                        return .init(message: note.message, line: noteLocation.line, column: noteLocation.column)
                    }
                ))
            }
        }
        let processor = DirectiveProcessor(configuration: configuration, knownRuleIDs: Set(registry.ruleIDs))
        return (processor.apply(violations, in: file, relativePath: relativePath).sorted(), internalErrors)
    }

    private struct FileResult: Sendable {
        let violations: [ReportedViolation]
        let internalErrors: [String]
    }

    private func lintFile(atPath path: String) -> FileResult {
        guard let data = FileManager.default.contents(atPath: path) else {
            return FileResult(violations: [], internalErrors: ["Can't read \(path)."])
        }
        let source = String(decoding: data, as: UTF8.self)
        if let cached = cache?.load(path: path, source: source) {
            return FileResult(violations: cached, internalErrors: [])
        }
        let result = lint(path: path, source: source)
        if result.internalErrors.isEmpty {
            cache?.store(result.violations, path: path, source: source)
        }
        return FileResult(violations: result.violations, internalErrors: result.internalErrors)
    }
}
