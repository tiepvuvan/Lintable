public protocol CatalogRule: Sendable {
    associatedtype Options: RuleOptions = NoOptions

    static var description: RuleDescription { get }

    init(options: Options)

    func check(_ catalog: StringCatalog) -> [Violation]
}

public extension CatalogRule where Options == NoOptions {
    init() {
        self.init(options: NoOptions())
    }
}
