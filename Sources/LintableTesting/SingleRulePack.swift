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
