public struct SummaryReporter: Reporter {
    public static let name = "summary"

    public init() {}

    public func render(_ result: LintResult) -> String {
        var lines: [String] = []
        var currentPath: String?
        for violation in result.violations {
            if violation.relativePath != currentPath {
                if currentPath != nil {
                    lines.append("")
                }
                lines.append(violation.relativePath)
                currentPath = violation.relativePath
            }
            let location = "\(violation.line):\(violation.column)"
            let severity = violation.severity.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
            lines.append("  \(location.padding(toLength: 8, withPad: " ", startingAt: 0)) \(severity) \(violation.message)  \(violation.ruleID)")
        }
        if !result.violations.isEmpty {
            lines.append("")
        }
        lines.append(summaryLine(result))
        if !result.releaseBlockers.isEmpty {
            let count = result.releaseBlockers.count
            lines.append("\(count) \(count == 1 ? "warning stops" : "warnings stop") release builds.")
        }
        let counts = Dictionary(grouping: result.violations, by: \.ruleID).mapValues(\.count)
        for id in counts.keys.sorted() {
            lines.append("  \(id.rawValue): \(counts[id] ?? 0)")
        }
        return lines.joined(separator: "\n")
    }

    private func summaryLine(_ result: LintResult) -> String {
        let files = "\(result.fileCount) \(result.fileCount == 1 ? "file" : "files")"
        guard !result.violations.isEmpty else {
            return "No violations in \(files)."
        }
        let errors = "\(result.errorCount) \(result.errorCount == 1 ? "error" : "errors")"
        let warnings = "\(result.warningCount) \(result.warningCount == 1 ? "warning" : "warnings")"
        let violatedFiles = Set(result.violations.map(\.relativePath)).count
        return "\(errors) and \(warnings) in \(violatedFiles) of \(files)."
    }
}

private extension String {
    func padding(toLength length: Int, withPad pad: String, startingAt _: Int) -> String {
        count >= length ? self : self + String(repeating: pad, count: length - count)
    }
}
