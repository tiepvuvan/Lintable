import SwiftSyntax

public enum AccessLevel: Int, Sendable, Hashable, Comparable, CaseIterable {
    case `private`
    case `fileprivate`
    case `internal`
    case `package`
    case `public`
    case `open`

    public var name: String {
        switch self {
        case .private: "private"
        case .fileprivate: "fileprivate"
        case .internal: "internal"
        case .package: "package"
        case .public: "public"
        case .open: "open"
        }
    }

    public static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func explicit(in modifiers: DeclModifierListSyntax) -> AccessLevel? {
        for modifier in modifiers where modifier.detail == nil {
            if let level = allCases.first(where: { $0.name == modifier.name.text }) {
                return level
            }
        }
        return nil
    }
}
