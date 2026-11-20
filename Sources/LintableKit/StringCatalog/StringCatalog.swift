import Foundation
import SwiftSyntax

public final class StringCatalog: Sendable {
    public let path: String
    public let source: String
    public let sourceLanguage: String
    public let entries: [Entry]
    public let targetLanguages: [String]
    private let lines: LineMap

    public init(path: String, source: String) throws {
        let lines = LineMap(source: source)
        let root: JSONValue
        do {
            root = try JSONDocument.parse(source)
        } catch let error as JSONParseError {
            let location = lines.location(ofUTF8Offset: error.utf8Offset)
            throw StringCatalogError(line: location.line, column: location.column, reason: error.reason)
        }
        guard case .object = root else {
            throw StringCatalogError(line: 1, column: 1, reason: "A String Catalog is a JSON object.")
        }
        let sourceLanguage = root["sourceLanguage"]?.string ?? "en"
        let entries = (root["strings"]?.members ?? []).map(Entry.init)
        self.path = path
        self.source = source
        self.sourceLanguage = sourceLanguage
        self.entries = entries
        targetLanguages = Set(entries.flatMap { $0.localizations.map(\.language) })
            .subtracting([sourceLanguage])
            .sorted()
        self.lines = lines
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

    public func sourceContent(of entry: Entry) -> Content {
        entry.localization(for: sourceLanguage)?.content ?? Content(text: entry.key, position: entry.position)
    }

    public func translations(of entry: Entry) -> [Localization] {
        entry.localizations.filter { $0.language != sourceLanguage }
    }
}

public struct StringCatalogError: Error, Sendable, Equatable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let reason: String

    public init(line: Int, column: Int, reason: String) {
        self.line = line
        self.column = column
        self.reason = reason
    }

    public var description: String {
        "Line \(line), column \(column): \(reason)"
    }
}
