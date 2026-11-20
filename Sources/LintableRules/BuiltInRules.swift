import LintableKit

public enum BuiltInRules: RulePack {
    public static let name = "Lintable"
    public static let version = LintableVersion.current
    public static let rules: [any Rule.Type] = [
        EnglishPluralLogicRule.self,
        HardcodedUITextRule.self,
        LayoutLifecycleRule.self,
        LocalizedConcatenationRule.self,
        NumberAsTextInLocalizedStringRule.self,
    ]
    public static let catalogRules: [any CatalogRule.Type] = [
        MissingPluralFormRule.self,
        MissingTranslationRule.self,
        MissingTranslatorCommentRule.self,
        NumberWithoutPluralRule.self,
        PlaceholderMismatchRule.self,
        PluralFormWithoutNumberRule.self,
        StaleStringRule.self,
    ]
}
