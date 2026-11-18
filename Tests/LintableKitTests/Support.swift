import LintableKit
import SwiftSyntax

struct MarkedFile {
    let file: LintFile
    let markers: [String: AbsolutePosition]

    init(_ source: String) {
        let parsed = Example(source).parse()
        file = LintFile(path: "Test.swift", source: parsed.source)
        markers = Dictionary(uniqueKeysWithValues: parsed.markers.map { ($0.name, AbsolutePosition(utf8Offset: $0.utf8Offset)) })
    }

    var index: SyntaxIndex {
        file.index
    }

    func token(_ marker: String) -> TokenSyntax? {
        markers[marker].flatMap { file.tree.token(at: $0) }
    }

    func node<T: SyntaxProtocol>(_ type: T.Type, at marker: String) -> T? {
        var current = token(marker).map(Syntax.init)
        while let node = current {
            if let match = node.as(T.self) {
                return match
            }
            current = node.parent
        }
        return nil
    }

    func all<T: SyntaxProtocol>(_ type: T.Type) -> [T] {
        let collector = NodeCollector<T>(viewMode: .sourceAccurate)
        collector.walk(file.tree)
        return collector.nodes
    }
}

final class NodeCollector<T: SyntaxProtocol>: SyntaxAnyVisitor {
    var nodes: [T] = []

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let match = node.as(T.self) {
            nodes.append(match)
        }
        return .visitChildren
    }
}
