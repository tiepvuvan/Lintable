public enum FileKind: String, Sendable, Codable, CaseIterable {
    case swift
    case stringCatalog

    public init?(path: String) {
        guard let kind = Self.allCases.first(where: { path.hasSuffix(".\($0.pathExtension)") }) else {
            return nil
        }
        self = kind
    }

    public var pathExtension: String {
        switch self {
        case .swift:
            "swift"
        case .stringCatalog:
            "xcstrings"
        }
    }
}
