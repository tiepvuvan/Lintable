import Foundation
import SwiftOperators
import SwiftParser
import SwiftSyntax

public final class LintFile: Sendable {
    public let path: String
    public let source: String
    public let tree: SourceFileSyntax
    public let index: SyntaxIndex
    private let lineStarts: [Int]

    public init(path: String, source: String) {
        self.path = path
        self.source = source
        let parsed = Parser.parse(source: source)
        tree = OperatorTable.standardOperators.foldAll(parsed) { _ in }.as(SourceFileSyntax.self) ?? parsed
        index = SyntaxIndex(tree: tree)
        lineStarts = Self.lineStarts(of: source)
    }

    public var hasSyntaxErrors: Bool {
        tree.hasError
    }

    public var lineCount: Int {
        lineStarts.count
    }

    public func location(of position: AbsolutePosition) -> LineColumn {
        let offset = position.utf8Offset
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= offset {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return LineColumn(line: low + 1, column: offset - lineStarts[low] + 1)
    }

    public func lineText(_ line: Int) -> String {
        guard line >= 1, line <= lineStarts.count else { return "" }
        let utf8 = source.utf8
        let start = utf8.index(utf8.startIndex, offsetBy: lineStarts[line - 1])
        let end = line < lineStarts.count ? utf8.index(utf8.startIndex, offsetBy: lineStarts[line]) : utf8.endIndex
        return String(decoding: utf8[start ..< end], as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lineStarts(of source: String) -> [Int] {
        var starts = [0]
        var offset = 0
        for byte in source.utf8 {
            offset += 1
            if byte == UInt8(ascii: "\n") {
                starts.append(offset)
            }
        }
        return starts
    }
}

public struct LineColumn: Sendable, Hashable, Comparable, Codable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: LineColumn, rhs: LineColumn) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}
