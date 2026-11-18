public struct XcodeReporter: Reporter {
    public static let name = "xcode"

    public init() {}

    public func render(_ result: LintResult) -> String {
        result.violations.map { violation in
            let main = "\(violation.path):\(violation.line):\(violation.column): \(violation.severity.rawValue): \(violation.message) (\(violation.ruleID))"
            let notes = violation.notes.map { "\(violation.path):\($0.line):\($0.column): note: \($0.message)" }
            return ([main] + notes).joined(separator: "\n")
        }
        .joined(separator: "\n")
    }
}
