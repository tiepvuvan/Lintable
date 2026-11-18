import LintableKit

public enum BuiltInRules: RulePack {
    public static let name = "Lintable"
    public static let version = LintableVersion.current
    public static let rules: [any Rule.Type] = [LayoutLifecycleRule.self]
}
