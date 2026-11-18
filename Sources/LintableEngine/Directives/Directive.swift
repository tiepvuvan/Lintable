import LintableKit

public struct Directive: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case disableNext = "disable:next"
        case disableThis = "disable:this"
        case disable
        case enable
    }

    public let kind: Kind
    public let ruleIDs: [RuleID]
    public let reason: String?
    public let line: Int
    public let column: Int
}

public struct InvalidDirective: Sendable, Hashable {
    public let text: String
    public let line: Int
    public let column: Int
}

public struct ParsedDirectives: Sendable {
    public let directives: [Directive]
    public let invalid: [InvalidDirective]
    public let codeLines: [Int]
}
