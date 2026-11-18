public struct RuleID: Hashable, Sendable, Comparable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String {
        rawValue
    }

    public var isWellFormed: Bool {
        guard let first = rawValue.unicodeScalars.first, ("a" ... "z").contains(first) else {
            return false
        }
        return rawValue.split(separator: "_", omittingEmptySubsequences: false).allSatisfy { word in
            !word.isEmpty && word.unicodeScalars.allSatisfy { ("a" ... "z").contains($0) || ("0" ... "9").contains($0) }
        }
    }

    public static func < (lhs: RuleID, rhs: RuleID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
