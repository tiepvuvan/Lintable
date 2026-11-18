import LintableKit

public struct ConfiguredRule: Sendable {
    public let id: RuleID
    public let description: RuleDescription
    public let severity: Severity
    public let optionsFingerprint: String
    private let body: @Sendable (LintFile) -> [Violation]

    init(
        id: RuleID,
        description: RuleDescription,
        severity: Severity,
        optionsFingerprint: String,
        body: @escaping @Sendable (LintFile) -> [Violation]
    ) {
        self.id = id
        self.description = description
        self.severity = severity
        self.optionsFingerprint = optionsFingerprint
        self.body = body
    }

    public func check(_ file: LintFile) -> [Violation] {
        body(file)
    }
}
