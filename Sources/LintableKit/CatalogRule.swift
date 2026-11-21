public protocol CatalogRule: Sendable {
    associatedtype Options: RuleOptions = NoOptions

    static var description: RuleDescription { get }

    init(options: Options)

    var referencedCatalogPaths: [String] { get }

    func check(_ catalog: StringCatalog) -> [Violation]

    func check(_ catalog: StringCatalog, in context: CatalogContext) -> [Violation]
}

public extension CatalogRule {
    var referencedCatalogPaths: [String] {
        []
    }

    func check(_ catalog: StringCatalog, in _: CatalogContext) -> [Violation] {
        check(catalog)
    }
}

public extension CatalogRule where Options == NoOptions {
    init() {
        self.init(options: NoOptions())
    }
}
