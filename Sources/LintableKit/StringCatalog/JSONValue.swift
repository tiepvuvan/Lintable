import SwiftSyntax

public enum JSONValue: Sendable, Equatable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    public var members: [JSONMember] {
        if case let .object(members) = self {
            return members
        }
        return []
    }

    public var elements: [JSONValue] {
        if case let .array(elements) = self {
            return elements
        }
        return []
    }

    public var string: String? {
        if case let .string(text) = self {
            return text
        }
        return nil
    }

    public var bool: Bool? {
        if case let .bool(flag) = self {
            return flag
        }
        return nil
    }

    public var integer: Int? {
        if case let .number(text) = self {
            return Int(text)
        }
        return nil
    }

    public func member(_ key: String) -> JSONMember? {
        members.first { $0.key == key }
    }

    public subscript(key: String) -> JSONValue? {
        member(key)?.value
    }
}

public struct JSONMember: Sendable, Equatable {
    public let key: String
    public let position: AbsolutePosition
    public let value: JSONValue

    public init(key: String, position: AbsolutePosition, value: JSONValue) {
        self.key = key
        self.position = position
        self.value = value
    }
}

public struct JSONParseError: Error, Sendable, Equatable, CustomStringConvertible {
    public let utf8Offset: Int
    public let reason: String

    public init(utf8Offset: Int, reason: String) {
        self.utf8Offset = utf8Offset
        self.reason = reason
    }

    public var description: String {
        reason
    }
}

public enum JSONDocument {
    public static func parse(_ source: String) throws -> JSONValue {
        var parser = JSONParser(bytes: Array(source.utf8))
        return try parser.parseDocument()
    }
}
