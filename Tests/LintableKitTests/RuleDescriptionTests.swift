import LintableKit
import Testing

@Suite struct RuleDescriptionTests {
    @Test func documentationDefaultsToLintablesRulePages() {
        let description = RuleDescription(id: "layout_lifecycle", name: "Layout lifecycle", summary: "", rationale: "", category: .layout)
        #expect(description.documentationURL == "https://github.com/tiepvuvan/Lintable/blob/main/docs/rules/layout_lifecycle.md")
    }

    @Test func customRulesLinkToTheirOwnDocumentation() {
        let description = RuleDescription(
            id: "no_print_in_views",
            name: "No print in views",
            summary: "",
            rationale: "",
            category: RuleCategory(id: "acme", name: "Acme conventions"),
            documentationURL: "https://example.com/acme-lint/rules/no_print_in_views"
        )
        #expect(description.documentationURL == "https://example.com/acme-lint/rules/no_print_in_views")
    }
}
