import Foundation
import LintableKit

public struct LintResult: Sendable {
    public let violations: [ReportedViolation]
    public let fileCount: Int
    public let rules: [RuleDescription]
    public let internalErrors: [String]
    public let releaseBlockers: [ReportedViolation]

    public init(
        violations: [ReportedViolation],
        fileCount: Int,
        rules: [RuleDescription],
        internalErrors: [String],
        releaseBlockers: [ReportedViolation] = []
    ) {
        self.violations = violations
        self.fileCount = fileCount
        self.rules = rules
        self.internalErrors = internalErrors
        self.releaseBlockers = releaseBlockers
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
    private let referencedCatalogs: [String: StringCatalog]
    private let referencedCatalogsFingerprint: String

    public init(
        configuration: Configuration,
        registry: RuleRegistry,
        cache: Cache? = nil,
        readFile: (URL) -> String? = Linter.readFile
    ) {
        self.configuration = configuration
        self.registry = registry
        self.cache = cache
        var catalogs: [String: StringCatalog] = [:]
        var fingerprintParts: [String] = []
        for path in Set(configuration.rules.flatMap(\.referencedCatalogPaths)).sorted() {
            let url = FileDiscovery.resolve(path, against: configuration.rootDirectory)
            guard let source = readFile(url) else {
                fingerprintParts.append("\(path)=missing")
                continue
            }
            fingerprintParts.append("\(path)=\(StableHash.hex(of: source))")
            catalogs[path] = try? StringCatalog(path: url.path, source: source)
        }
        referencedCatalogs = catalogs
        referencedCatalogsFingerprint = StableHash.hex(of: fingerprintParts.joined(separator: "\n"))
    }

    public static func readFile(_ url: URL) -> String? {
        FileManager.default.contents(atPath: url.path).map { String(decoding: $0, as: UTF8.self) }
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
        let blockingRules = Set(configuration.rules.filter(\.blocksReleaseBuilds).map(\.id))
        let descriptions = configuration.rules.map(\.description) + EngineRules.descriptions
        return LintResult(
            violations: violations,
            fileCount: files.count,
            rules: descriptions.sorted { $0.id < $1.id },
            internalErrors: results.flatMap(\.internalErrors).sorted(),
            releaseBlockers: violations.filter { blockingRules.contains($0.ruleID) }
        )
    }

    public func lint(path: String, source: String) -> (violations: [ReportedViolation], internalErrors: [String]) {
        if FileKind(path: path) == .stringCatalog {
            return lintCatalog(path: path, source: source)
        }
        return lintSwift(path: path, source: source)
    }

    private func lintSwift(path: String, source: String) -> (violations: [ReportedViolation], internalErrors: [String]) {
        let file = LintFile(path: path, source: source)
        let relativePath = FileDiscovery.relativePath(of: path, root: configuration.rootDirectory)
        let report = ViolationReport(
            path: path,
            relativePath: relativePath,
            length: source.utf8.count,
            location: file.location(ofUTF8Offset:),
            lineText: file.lineText
        )
        var violations: [ReportedViolation] = []
        var internalErrors: [String] = []
        for rule in configuration.rules where rule.fileKind == .swift {
            report.add(rule.check(file), from: rule, to: &violations, errors: &internalErrors)
        }
        let processor = DirectiveProcessor(configuration: configuration, knownRuleIDs: Set(registry.ruleIDs))
        return (processor.apply(violations, in: file, relativePath: relativePath).sorted(), internalErrors)
    }

    private func lintCatalog(path: String, source: String) -> (violations: [ReportedViolation], internalErrors: [String]) {
        let rules = configuration.rules.filter { $0.fileKind == .stringCatalog }
        guard !rules.isEmpty else { return ([], []) }
        let relativePath = FileDiscovery.relativePath(of: path, root: configuration.rootDirectory)
        let catalog: StringCatalog
        do {
            catalog = try StringCatalog(path: path, source: source)
        } catch {
            return ([], ["\(relativePath) isn't a valid String Catalog. \(error)"])
        }
        let report = ViolationReport(
            path: path,
            relativePath: relativePath,
            length: source.utf8.count,
            location: catalog.location(ofUTF8Offset:),
            lineText: catalog.lineText
        )
        var violations: [ReportedViolation] = []
        var internalErrors: [String] = []
        let context = CatalogContext(relativePath: relativePath, catalogs: referencedCatalogs)
        for rule in rules {
            report.add(rule.check(catalog, in: context), from: rule, to: &violations, errors: &internalErrors)
        }
        return (violations.sorted(), internalErrors)
    }

    private struct FileResult: Sendable {
        let violations: [ReportedViolation]
        let internalErrors: [String]
    }

    private func lintFile(atPath path: String) -> FileResult {
        if FileKind(path: path) == .stringCatalog, !configuration.hasCatalogRules {
            return FileResult(violations: [], internalErrors: [])
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return FileResult(violations: [], internalErrors: ["Can't read \(path)."])
        }
        let source = String(decoding: data, as: UTF8.self)
        let cacheKey = FileKind(path: path) == .stringCatalog ? source + "\n" + referencedCatalogsFingerprint : source
        if let cached = cache?.load(path: path, source: cacheKey) {
            return FileResult(violations: cached, internalErrors: [])
        }
        let result = lint(path: path, source: source)
        if result.internalErrors.isEmpty {
            cache?.store(result.violations, path: path, source: cacheKey)
        }
        return FileResult(violations: result.violations, internalErrors: result.internalErrors)
    }
}

private struct ViolationReport {
    let path: String
    let relativePath: String
    let length: Int
    let location: (Int) -> LineColumn
    let lineText: (Int) -> String

    func add(_ found: [Violation], from rule: ConfiguredRule, to violations: inout [ReportedViolation], errors: inout [String]) {
        for violation in found {
            guard violation.position.utf8Offset >= 0, violation.position.utf8Offset <= length else {
                errors.append("Rule `\(rule.id)` reported a position outside \(relativePath).")
                continue
            }
            let place = location(violation.position.utf8Offset)
            violations.append(ReportedViolation(
                ruleID: rule.id,
                severity: rule.severity,
                message: violation.message,
                path: path,
                relativePath: relativePath,
                line: place.line,
                column: place.column,
                lineText: lineText(place.line),
                notes: violation.notes.map { note in
                    let notePlace = location(note.position.utf8Offset)
                    return .init(message: note.message, line: notePlace.line, column: notePlace.column)
                }
            ))
        }
    }
}
