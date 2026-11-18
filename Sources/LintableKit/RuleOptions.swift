public protocol RuleOptions: Codable, Sendable, Equatable {
    init()
}

public struct NoOptions: RuleOptions {
    public init() {}
}
