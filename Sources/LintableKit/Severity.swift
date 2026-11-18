public enum Severity: String, Sendable, Codable, CaseIterable, Comparable {
    case warning
    case error

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs == .warning && rhs == .error
    }
}
