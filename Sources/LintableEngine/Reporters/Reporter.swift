public protocol Reporter: Sendable {
    static var name: String { get }

    func render(_ result: LintResult) -> String
}

public enum Reporters {
    public static let all: [any Reporter] = [
        XcodeReporter(),
        SummaryReporter(),
        JSONReporter(),
        SARIFReporter(),
        GitHubReporter(),
    ]

    public static var names: [String] {
        all.map { type(of: $0).name }
    }

    public static func named(_ name: String) -> (any Reporter)? {
        all.first { type(of: $0).name == name }
    }
}
