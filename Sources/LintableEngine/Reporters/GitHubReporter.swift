public struct GitHubReporter: Reporter {
    public static let name = "github"

    public init() {}

    public func render(_ result: LintResult) -> String {
        result.violations.map { violation in
            let properties = [
                "file=\(escapeProperty(violation.relativePath))",
                "line=\(violation.line)",
                "col=\(violation.column)",
                "title=\(escapeProperty(violation.ruleID.rawValue))",
            ]
            return "::\(violation.severity.rawValue) \(properties.joined(separator: ","))::\(escapeData(violation.message))"
        }
        .joined(separator: "\n")
    }

    private func escapeData(_ text: String) -> String {
        text.replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
    }

    private func escapeProperty(_ text: String) -> String {
        escapeData(text)
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ",", with: "%2C")
    }
}
