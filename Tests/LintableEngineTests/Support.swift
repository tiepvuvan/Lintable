import Foundation
import LintableEngine
import LintableKit
import SwiftSyntax

struct ForbiddenNameRule: Rule {
    struct Options: RuleOptions {
        var names = ["forbidden"]
        var reportCalls = true
    }

    static let description = RuleDescription(
        id: "forbidden_name",
        name: "Forbidden name",
        summary: "An identifier that the config forbids.",
        rationale: "A rule for testing the engine.",
        category: RuleCategory(id: "test", name: "Test"),
        defaultSeverity: .error,
        optionDescriptions: ["names": "Identifiers to report.", "report_calls": "Also report calls."],
        triggeringExamples: [Example("let value = 1️⃣forbidden")],
        nonTriggeringExamples: [Example("let value = allowed")]
    )

    let options: Options

    func check(_ file: LintFile) -> [Violation] {
        let visitor = NameVisitor(names: Set(options.names))
        visitor.walk(file.tree)
        return visitor.found.map { Violation(at: $0, message: "`\($0.baseName.text)` is forbidden.") }
    }
}

final class NameVisitor: SyntaxVisitor {
    let names: Set<String>
    var found: [DeclReferenceExprSyntax] = []

    init(names: Set<String>) {
        self.names = names
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        if names.contains(node.baseName.text) {
            found.append(node)
        }
        return .visitChildren
    }
}

struct OutOfBoundsRule: Rule {
    static let description = RuleDescription(
        id: "out_of_bounds",
        name: "Out of bounds",
        summary: "Reports past the end of the file.",
        rationale: "A broken rule for testing the engine.",
        category: RuleCategory(id: "test", name: "Test")
    )

    init(options _: NoOptions) {}

    func check(_ file: LintFile) -> [Violation] {
        [Violation(position: AbsolutePosition(utf8Offset: file.source.utf8.count + 10), message: "Out of bounds.")]
    }
}

enum TestRules: RulePack {
    static let name = "Test"
    static let version = "1"
    static let rules: [any Rule.Type] = [ForbiddenNameRule.self]
}

enum BrokenRules: RulePack {
    static let name = "Broken"
    static let version = "1"
    static let rules: [any Rule.Type] = [OutOfBoundsRule.self]
}

struct ForbiddenKeyRule: CatalogRule {
    static let description = RuleDescription(
        id: "forbidden_key",
        name: "Forbidden key",
        summary: "A String Catalog key named forbidden.",
        rationale: "A catalog rule for testing the engine.",
        category: RuleCategory(id: "test", name: "Test"),
        fileKind: .stringCatalog
    )

    init(options _: NoOptions) {}

    func check(_ catalog: StringCatalog) -> [Violation] {
        catalog.entries.filter { $0.key == "forbidden" }.map { Violation(position: $0.position, message: "The key is forbidden.") }
    }
}

struct SharedKeysRule: CatalogRule {
    struct Options: RuleOptions {
        var source = ""
    }

    static let description = RuleDescription(
        id: "shared_keys",
        name: "Shared keys",
        summary: "A String Catalog lacks a key of another catalog.",
        rationale: "A catalog rule that reads another catalog, for testing the engine.",
        category: RuleCategory(id: "test", name: "Test"),
        fileKind: .stringCatalog
    )

    let options: Options

    init(options: Options) {
        self.options = options
    }

    var referencedCatalogPaths: [String] {
        [options.source]
    }

    func check(_ catalog: StringCatalog) -> [Violation] {
        []
    }

    func check(_ catalog: StringCatalog, in context: CatalogContext) -> [Violation] {
        guard !context.isCatalog(atPath: options.source) else { return [] }
        let keys = Set(catalog.entries.map(\.key))
        let missing = context.catalog(atPath: options.source)?.entries.map(\.key).filter { !keys.contains($0) } ?? ["(unreadable)"]
        return missing.map { Violation(position: AbsolutePosition(utf8Offset: 0), message: "Missing \($0) from \(context.relativePath).") }
    }
}

enum CatalogTestRules: RulePack {
    static let name = "CatalogTest"
    static let version = "1"
    static let rules: [any Rule.Type] = [ForbiddenNameRule.self]
    static let catalogRules: [any CatalogRule.Type] = [ForbiddenKeyRule.self, SharedKeysRule.self]
}

let forbiddenKeyCatalog = """
{
  "sourceLanguage" : "en",
  "strings" : {
    "allowed" : { },
    "forbidden" : { }
  },
  "version" : "1.0"
}
"""

final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LintableTests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func write(_ relativePath: String, _ contents: String) throws -> URL {
        let file = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: file)
        return file
    }
}

func registry(_ packs: [any RulePack.Type] = [TestRules.self]) throws -> RuleRegistry {
    try RuleRegistry(packs: packs)
}

func configuration(_ yaml: String, root: URL = URL(fileURLWithPath: "/tmp/project"), packs: [any RulePack.Type] = [TestRules.self]) throws -> Configuration {
    try Configuration.parse(yaml: yaml, rootDirectory: root, registry: registry(packs))
}

func lint(_ source: String, config yaml: String = "rules:\n  forbidden_name:", packs: [any RulePack.Type] = [TestRules.self]) throws -> [ReportedViolation] {
    let configuration = try configuration(yaml, packs: packs)
    let linter = try Linter(configuration: configuration, registry: registry(packs))
    return linter.lint(path: "/tmp/project/Sources/A.swift", source: source).violations
}
