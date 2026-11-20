public struct FormatSpecifier: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case value(conversion: String)
        case substitution(name: String)
        case substitutionArgument
    }

    public enum Family: String, Sendable, Hashable {
        case integer
        case float
        case object
        case cString
        case character
        case pointer
    }

    public let text: String
    public let kind: Kind
    public let argumentIndex: Int?
    public let utf8Range: Range<Int>

    public init(text: String, kind: Kind, argumentIndex: Int?, utf8Range: Range<Int>) {
        self.text = text
        self.kind = kind
        self.argumentIndex = argumentIndex
        self.utf8Range = utf8Range
    }

    public var family: Family? {
        guard case let .value(conversion) = kind else { return nil }
        return Self.family(ofConversion: conversion)
    }

    public var isInteger: Bool {
        family == .integer
    }

    public var showsNumber: Bool {
        switch kind {
        case .value:
            family == .integer || family == .float
        case .substitution, .substitutionArgument:
            true
        }
    }

    public static func family(ofConversion conversion: String) -> Family? {
        switch conversion.last {
        case "d", "D", "i", "u", "U", "x", "X", "o", "O":
            .integer
        case "f", "F", "e", "E", "g", "G", "a", "A":
            .float
        case "@":
            .object
        case "s", "S":
            .cString
        case "c", "C":
            .character
        case "p":
            .pointer
        default:
            nil
        }
    }

    public static func parse(_ text: String) -> [FormatSpecifier] {
        var scanner = Scanner(bytes: Array(text.utf8))
        return scanner.specifiers()
    }
}

private struct Scanner {
    private static let flags = Set("-+#0'".utf8)
    private static let conversions = Set("@dDiuUxXoOfFeEgGcCsSpaA".utf8)
    private static let lengthModifiers = ["hh", "ll", "h", "l", "q", "L", "z", "t", "j"].map { Array($0.utf8) }

    let bytes: [UInt8]
    var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func specifiers() -> [FormatSpecifier] {
        var found: [FormatSpecifier] = []
        while index < bytes.count {
            guard bytes[index] == UInt8(ascii: "%") else {
                index += 1
                continue
            }
            if index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "%") {
                index += 2
                continue
            }
            let start = index
            if let specifier = scanSpecifier(startingAt: start) {
                found.append(specifier)
            } else {
                index = start + 1
            }
        }
        return found
    }

    private mutating func scanSpecifier(startingAt start: Int) -> FormatSpecifier? {
        index = start + 1
        if matches("arg") {
            index += 3
            return FormatSpecifier(text: "%arg", kind: .substitutionArgument, argumentIndex: nil, utf8Range: start ..< index)
        }
        let argumentIndex = scanArgumentIndex()
        if matches("#@") {
            return scanSubstitution(startingAt: start, argumentIndex: argumentIndex)
        }
        skip(while: { Self.flags.contains($0) })
        skip(while: { (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) || $0 == UInt8(ascii: "*") })
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            skip(while: { (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) || $0 == UInt8(ascii: "*") })
        }
        let conversionStart = index
        if let modifier = Self.lengthModifiers.first(where: { matches($0) }) {
            index += modifier.count
        }
        guard index < bytes.count, Self.conversions.contains(bytes[index]) else { return nil }
        index += 1
        return FormatSpecifier(
            text: String(decoding: bytes[start ..< index], as: UTF8.self),
            kind: .value(conversion: String(decoding: bytes[conversionStart ..< index], as: UTF8.self)),
            argumentIndex: argumentIndex,
            utf8Range: start ..< index
        )
    }

    private mutating func scanArgumentIndex() -> Int? {
        var end = index
        while end < bytes.count, (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(bytes[end]) {
            end += 1
        }
        guard end > index, end < bytes.count, bytes[end] == UInt8(ascii: "$") else { return nil }
        let number = Int(String(decoding: bytes[index ..< end], as: UTF8.self))
        index = end + 1
        return number
    }

    private mutating func scanSubstitution(startingAt start: Int, argumentIndex: Int?) -> FormatSpecifier? {
        let nameStart = index + 2
        guard let close = bytes[nameStart...].firstIndex(of: UInt8(ascii: "@")) else { return nil }
        index = close + 1
        return FormatSpecifier(
            text: String(decoding: bytes[start ..< index], as: UTF8.self),
            kind: .substitution(name: String(decoding: bytes[nameStart ..< close], as: UTF8.self)),
            argumentIndex: argumentIndex,
            utf8Range: start ..< index
        )
    }

    private func matches(_ text: String) -> Bool {
        matches(Array(text.utf8))
    }

    private func matches(_ expected: [UInt8]) -> Bool {
        index + expected.count <= bytes.count && Array(bytes[index ..< index + expected.count]) == expected
    }

    private mutating func skip(while predicate: (UInt8) -> Bool) {
        while index < bytes.count, predicate(bytes[index]) {
            index += 1
        }
    }
}
