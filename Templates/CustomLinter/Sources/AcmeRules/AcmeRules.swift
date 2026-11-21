import LintableKit

public enum AcmeRules: RulePack {
    public static let name = "AcmeRules"
    public static let version = "1.0.0"
    public static let rules: [any Rule.Type] = [
        NoPrintInViewsRule.self,
    ]
}

public extension RuleCategory {
    static let acme = RuleCategory(id: "acme", name: "Acme conventions")
}
