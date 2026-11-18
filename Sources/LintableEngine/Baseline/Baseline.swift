import Foundation
import LintableKit

public struct Baseline: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Hashable, Comparable {
        public let rule: RuleID
        public let path: String
        public let line: String
        public let message: String

        public init(rule: RuleID, path: String, line: String, message: String) {
            self.rule = rule
            self.path = path
            self.line = line
            self.message = message
        }

        init(_ violation: ReportedViolation) {
            self.init(rule: violation.ruleID, path: violation.relativePath, line: violation.lineText, message: violation.message)
        }

        public static func < (lhs: Entry, rhs: Entry) -> Bool {
            (lhs.path, lhs.rule.rawValue, lhs.line, lhs.message) < (rhs.path, rhs.rule.rawValue, rhs.line, rhs.message)
        }
    }

    public var version: Int
    public var entries: [Entry]

    public init(violations: [ReportedViolation]) {
        version = 1
        entries = violations.map(Entry.init).sorted()
    }

    public static func load(from url: URL) throws -> Baseline {
        try JSONDecoder().decode(Baseline.self, from: Data(contentsOf: url))
    }

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(contentsOf: Array("\n".utf8))
        try data.write(to: url, options: .atomic)
    }

    public func filter(_ violations: [ReportedViolation]) -> [ReportedViolation] {
        var remaining: [Entry: Int] = [:]
        for entry in entries {
            remaining[entry, default: 0] += 1
        }
        return violations.filter { violation in
            let entry = Entry(violation)
            guard let count = remaining[entry], count > 0 else { return true }
            remaining[entry] = count - 1
            return false
        }
    }
}
