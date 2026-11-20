import LintableKit

public struct ConfiguredRule: Sendable {
    enum Body: Sendable {
        case swift(@Sendable (LintFile) -> [Violation])
        case stringCatalog(@Sendable (StringCatalog) -> [Violation])
    }

    public let id: RuleID
    public let description: RuleDescription
    public let severity: Severity
    public let releaseSeverity: Severity?
    public let optionsFingerprint: String
    private let body: Body

    init(
        id: RuleID,
        description: RuleDescription,
        severity: Severity,
        releaseSeverity: Severity?,
        optionsFingerprint: String,
        body: Body
    ) {
        self.id = id
        self.description = description
        self.severity = severity
        self.releaseSeverity = releaseSeverity
        self.optionsFingerprint = optionsFingerprint
        self.body = body
    }

    public var fileKind: FileKind {
        switch body {
        case .swift:
            .swift
        case .stringCatalog:
            .stringCatalog
        }
    }

    public var blocksReleaseBuilds: Bool {
        releaseSeverity.map { $0 > severity } ?? false
    }

    public func check(_ file: LintFile) -> [Violation] {
        guard case let .swift(check) = body else { return [] }
        return check(file)
    }

    public func check(_ catalog: StringCatalog) -> [Violation] {
        guard case let .stringCatalog(check) = body else { return [] }
        return check(catalog)
    }
}
