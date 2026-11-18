import LintableKit

public enum EngineRules {
    public static let invalidDirective: RuleID = "invalid_directive"
    public static let unknownRule: RuleID = "unknown_rule"
    public static let missingReason: RuleID = "missing_reason"
    public static let superfluousDirective: RuleID = "superfluous_directive"

    public static let ids: Set<RuleID> = [invalidDirective, unknownRule, missingReason, superfluousDirective]

    public static let descriptions: [RuleDescription] = [
        RuleDescription(
            id: invalidDirective,
            name: "Invalid directive",
            summary: "A `// lintable:` comment that isn't a valid directive.",
            rationale: "A typo in a directive silently suppresses nothing, so Lintable reports it.",
            category: .engine
        ),
        RuleDescription(
            id: unknownRule,
            name: "Unknown rule",
            summary: "A directive names a rule that isn't loaded.",
            rationale: "The directive suppresses nothing, usually because of a typo or a removed rule.",
            category: .engine
        ),
        RuleDescription(
            id: missingReason,
            name: "Missing reason",
            summary: "A directive has no reason after ` - `.",
            rationale: "A reason tells the next reader why the rule doesn't apply here. Turn this off with `require_reasons: false`.",
            category: .engine
        ),
        RuleDescription(
            id: superfluousDirective,
            name: "Superfluous directive",
            summary: "A directive suppresses no violation.",
            rationale: "Directives that suppress nothing hide future violations on the same lines and go stale.",
            category: .engine
        ),
    ]
}
