import Foundation

public struct JSONReporter: Reporter {
    public static let name = "json"

    struct Item: Encodable {
        let rule: String
        let severity: String
        let message: String
        let path: String
        let line: Int
        let column: Int
        let documentation: String?
    }

    public init() {}

    public func render(_ result: LintResult) -> String {
        let documentation = Dictionary(uniqueKeysWithValues: result.rules.map { ($0.id, $0.documentationURL) })
        let items = result.violations.map { violation in
            Item(
                rule: violation.ruleID.rawValue,
                severity: violation.severity.rawValue,
                message: violation.message,
                path: violation.relativePath,
                line: violation.line,
                column: violation.column,
                documentation: documentation[violation.ruleID]
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(items)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }
}
