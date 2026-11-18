public protocol RulePack: Sendable {
    static var name: String { get }
    static var version: String { get }
    static var rules: [any Rule.Type] { get }
}
