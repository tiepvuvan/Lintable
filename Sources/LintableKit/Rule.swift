public protocol Rule: Sendable {
    associatedtype Options: RuleOptions = NoOptions

    static var description: RuleDescription { get }

    init(options: Options)

    func check(_ file: LintFile) -> [Violation]
}

public extension Rule where Options == NoOptions {
    init() {
        self.init(options: NoOptions())
    }
}
