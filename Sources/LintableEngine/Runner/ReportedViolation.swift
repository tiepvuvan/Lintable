import LintableKit

public struct ReportedViolation: Sendable, Hashable, Codable, Comparable {
    public struct ReportedNote: Sendable, Hashable, Codable {
        public let message: String
        public let line: Int
        public let column: Int

        public init(message: String, line: Int, column: Int) {
            self.message = message
            self.line = line
            self.column = column
        }
    }

    public let ruleID: RuleID
    public let severity: Severity
    public let message: String
    public let path: String
    public let relativePath: String
    public let line: Int
    public let column: Int
    public let lineText: String
    public let notes: [ReportedNote]

    public init(
        ruleID: RuleID,
        severity: Severity,
        message: String,
        path: String,
        relativePath: String,
        line: Int,
        column: Int,
        lineText: String,
        notes: [ReportedNote] = []
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.path = path
        self.relativePath = relativePath
        self.line = line
        self.column = column
        self.lineText = lineText
        self.notes = notes
    }

    public static func < (lhs: ReportedViolation, rhs: ReportedViolation) -> Bool {
        (lhs.relativePath, lhs.line, lhs.column, lhs.ruleID.rawValue, lhs.message)
            < (rhs.relativePath, rhs.line, rhs.column, rhs.ruleID.rawValue, rhs.message)
    }
}
