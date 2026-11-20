public struct RuleDescription: Sendable {
    public var id: RuleID
    public var name: String
    public var summary: String
    public var rationale: String
    public var category: RuleCategory
    public var defaultSeverity: Severity
    public var optionDescriptions: [String: String]
    public var triggeringExamples: [Example]
    public var nonTriggeringExamples: [Example]
    public var howToFix: String
    public var fileKind: FileKind

    public init(
        id: RuleID,
        name: String,
        summary: String,
        rationale: String,
        category: RuleCategory,
        defaultSeverity: Severity = .warning,
        optionDescriptions: [String: String] = [:],
        triggeringExamples: [Example] = [],
        nonTriggeringExamples: [Example] = [],
        howToFix: String = "",
        fileKind: FileKind = .swift
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.rationale = rationale
        self.category = category
        self.defaultSeverity = defaultSeverity
        self.optionDescriptions = optionDescriptions
        self.triggeringExamples = triggeringExamples
        self.nonTriggeringExamples = nonTriggeringExamples
        self.howToFix = howToFix
        self.fileKind = fileKind
    }

    public var documentationURL: String {
        "https://github.com/tiepvuvan/Lintable/blob/main/docs/rules/\(id.rawValue).md"
    }
}
