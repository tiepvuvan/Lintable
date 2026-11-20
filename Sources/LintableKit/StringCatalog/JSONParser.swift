import SwiftSyntax

struct JSONParser {
    private let bytes: [UInt8]
    private var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parseDocument() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        guard index == bytes.count else {
            throw failure("Expected the end of the file after the JSON value.")
        }
        return value
    }

    private mutating func parseValue() throws -> JSONValue {
        guard index < bytes.count else {
            throw failure("Expected a value.")
        }
        switch bytes[index] {
        case UInt8(ascii: "{"):
            return try parseObject()
        case UInt8(ascii: "["):
            return try parseArray()
        case UInt8(ascii: "\""):
            return try .string(parseString())
        case UInt8(ascii: "t"):
            try expectWord("true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try expectWord("false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try expectWord("null")
            return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return try .number(parseNumber())
        default:
            throw failure("Expected a value.")
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        index += 1
        var members: [JSONMember] = []
        skipWhitespace()
        if consume(UInt8(ascii: "}")) {
            return .object(members)
        }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else {
                throw failure("Expected a key in double quotes.")
            }
            let position = AbsolutePosition(utf8Offset: index)
            let key = try parseString()
            skipWhitespace()
            guard consume(UInt8(ascii: ":")) else {
                throw failure("Expected `:` after the key.")
            }
            skipWhitespace()
            let value = try parseValue()
            members.append(JSONMember(key: key, position: position, value: value))
            skipWhitespace()
            if consume(UInt8(ascii: ",")) {
                continue
            }
            if consume(UInt8(ascii: "}")) {
                return .object(members)
            }
            throw failure("Expected `,` or `}` in the object.")
        }
    }

    private mutating func parseArray() throws -> JSONValue {
        index += 1
        var elements: [JSONValue] = []
        skipWhitespace()
        if consume(UInt8(ascii: "]")) {
            return .array(elements)
        }
        while true {
            skipWhitespace()
            elements.append(try parseValue())
            skipWhitespace()
            if consume(UInt8(ascii: ",")) {
                continue
            }
            if consume(UInt8(ascii: "]")) {
                return .array(elements)
            }
            throw failure("Expected `,` or `]` in the array.")
        }
    }

    private mutating func parseString() throws -> String {
        index += 1
        let start = index
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "\""):
                let text = String(decoding: bytes[start ..< index], as: UTF8.self)
                index += 1
                return text
            case UInt8(ascii: "\\"):
                return try parseEscapedString(startingAt: start)
            default:
                index += 1
            }
        }
        throw failure("The string isn't closed.")
    }

    private mutating func parseEscapedString(startingAt start: Int) throws -> String {
        var buffer = Array(bytes[start ..< index])
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            switch byte {
            case UInt8(ascii: "\""):
                return String(decoding: buffer, as: UTF8.self)
            case UInt8(ascii: "\\"):
                try appendEscape(to: &buffer)
            default:
                buffer.append(byte)
            }
        }
        throw failure("The string isn't closed.")
    }

    private mutating func appendEscape(to buffer: inout [UInt8]) throws {
        guard index < bytes.count else {
            throw failure("The string isn't closed.")
        }
        let byte = bytes[index]
        index += 1
        switch byte {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"):
            buffer.append(byte)
        case UInt8(ascii: "b"):
            buffer.append(0x08)
        case UInt8(ascii: "f"):
            buffer.append(0x0C)
        case UInt8(ascii: "n"):
            buffer.append(0x0A)
        case UInt8(ascii: "r"):
            buffer.append(0x0D)
        case UInt8(ascii: "t"):
            buffer.append(0x09)
        case UInt8(ascii: "u"):
            let scalar = try parseUnicodeEscape()
            UTF8.encode(scalar) { buffer.append($0) }
        default:
            index -= 1
            throw failure("Unknown escape `\\\(Character(Unicode.Scalar(byte)))` in the string.")
        }
    }

    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let high = try parseHexQuad()
        var value = high
        if (0xD800 ... 0xDBFF).contains(high) {
            guard index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") else {
                throw failure("The surrogate pair is incomplete.")
            }
            index += 2
            let low = try parseHexQuad()
            guard (0xDC00 ... 0xDFFF).contains(low) else {
                throw failure("The surrogate pair is invalid.")
            }
            value = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
        }
        guard let scalar = Unicode.Scalar(value) else {
            throw failure("The `\\u` escape isn't a valid character.")
        }
        return scalar
    }

    private mutating func parseHexQuad() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0 ..< 4 {
            guard index < bytes.count, let digit = Self.hexValue(of: bytes[index]) else {
                throw failure("A `\\u` escape needs four hexadecimal digits.")
            }
            value = value * 16 + digit
            index += 1
        }
        return value
    }

    private mutating func parseNumber() throws -> String {
        let start = index
        _ = consume(UInt8(ascii: "-"))
        guard consumeDigits() else {
            throw failure("Expected digits in the number.")
        }
        if consume(UInt8(ascii: ".")), !consumeDigits() {
            throw failure("Expected digits after the decimal point.")
        }
        if consume(UInt8(ascii: "e")) || consume(UInt8(ascii: "E")) {
            _ = consume(UInt8(ascii: "+")) || consume(UInt8(ascii: "-"))
            guard consumeDigits() else {
                throw failure("Expected digits in the exponent.")
            }
        }
        return String(decoding: bytes[start ..< index], as: UTF8.self)
    }

    private mutating func expectWord(_ word: String) throws {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index ..< index + expected.count]) == expected else {
            throw failure("Expected a value.")
        }
        index += expected.count
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private mutating func consumeDigits() -> Bool {
        let start = index
        while index < bytes.count, (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(bytes[index]) {
            index += 1
        }
        return index > start
    }

    private mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) {
            index += 1
        }
    }

    private func failure(_ reason: String) -> JSONParseError {
        JSONParseError(utf8Offset: min(index, bytes.count), reason: reason)
    }

    private static func hexValue(of byte: UInt8) -> UInt32? {
        switch byte {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"):
            UInt32(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a") ... UInt8(ascii: "f"):
            UInt32(byte - UInt8(ascii: "a") + 10)
        case UInt8(ascii: "A") ... UInt8(ascii: "F"):
            UInt32(byte - UInt8(ascii: "A") + 10)
        default:
            nil
        }
    }
}
