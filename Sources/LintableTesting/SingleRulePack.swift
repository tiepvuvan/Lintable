import LintableKit

struct SingleRulePack<R: Rule>: RulePack {
    static var name: String {
        "LintableTesting"
    }

    static var version: String {
        "0"
    }

    static var rules: [any Rule.Type] {
        [R.self]
    }
}

struct SingleCatalogRulePack<R: CatalogRule>: RulePack {
    static var name: String {
        "LintableTesting"
    }

    static var version: String {
        "0"
    }

    static var rules: [any Rule.Type] {
        []
    }

    static var catalogRules: [any CatalogRule.Type] {
        [R.self]
    }
}
