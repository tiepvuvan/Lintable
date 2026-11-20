import Foundation
import SwiftOperators
import SwiftParser
import SwiftSyntax

public final class LintFile: Sendable {
    public let path: String
    public let source: String
    public let tree: SourceFileSyntax
    public let index: SyntaxIndex
    private let lines: LineMap

    public init(path: String, source: String) {
        self.path = path
        self.source = source
        let parsed = Parser.parse(source: source)
        tree = OperatorTable.standardOperators.foldAll(parsed) { _ in }.as(SourceFileSyntax.self) ?? parsed
        index = SyntaxIndex(tree: tree)
        lines = LineMap(source: source)
    }

    public var hasSyntaxErrors: Bool {
        tree.hasError
    }

    public var lineCount: Int {
        lines.lineCount
    }

    public func location(of position: AbsolutePosition) -> LineColumn {
        lines.location(ofUTF8Offset: position.utf8Offset)
    }

    public func location(ofUTF8Offset offset: Int) -> LineColumn {
        lines.location(ofUTF8Offset: offset)
    }

    public func lineText(_ line: Int) -> String {
        lines.lineText(line)
    }
}
