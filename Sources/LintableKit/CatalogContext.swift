public struct CatalogContext: Sendable {
    public let relativePath: String
    private let catalogs: [String: StringCatalog]

    public init(relativePath: String, catalogs: [String: StringCatalog] = [:]) {
        self.relativePath = relativePath
        self.catalogs = catalogs
    }

    public func catalog(atPath path: String) -> StringCatalog? {
        catalogs[path]
    }

    public func isCatalog(atPath path: String) -> Bool {
        Self.normalized(path) == Self.normalized(relativePath)
    }

    static func normalized(_ path: String) -> String {
        path.split(separator: "/").filter { $0 != "." }.joined(separator: "/")
    }
}
