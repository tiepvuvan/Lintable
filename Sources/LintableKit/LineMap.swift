import Foundation

public struct LineMap: Sendable {
    public let source: String
    private let lineStarts: [Int]

    public init(source: String) {
        self.source = source
        var starts = [0]
        var offset = 0
        for byte in source.utf8 {
            offset += 1
            if byte == UInt8(ascii: "\n") {
                starts.append(offset)
            }
        }
        lineStarts = starts
    }

    public var lineCount: Int {
        lineStarts.count
    }

    public func location(ofUTF8Offset offset: Int) -> LineColumn {
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
