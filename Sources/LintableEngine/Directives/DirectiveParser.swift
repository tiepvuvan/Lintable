import Foundation
import LintableKit
import SwiftSyntax

public enum DirectiveParser {
    public static let prefix = "lintable:"

    public static func parse(_ file: LintFile) -> ParsedDirectives {
        var directives: [Directive] = []
        var invalid: [InvalidDirective] = []
        var codeLines = Set<Int>()
        for token in file.tree.tokens(viewMode: .sourceAccurate) {
            if token.tokenKind != .endOfFile {
                codeLines.insert(file.location(of: token.positionAfterSkippingLeadingTrivia).line)
            }
            scan(token.leadingTrivia, startingAt: token.position, in: file, directives: &directives, invalid: &invalid)
            scan(token.trailingTrivia, startingAt: token.endPositionBeforeTrailingTrivia, in: file, directives: &directives, invalid: &invalid)
        }
        return ParsedDirectives(directives: directives, invalid: invalid, codeLines: codeLines.sorted())
    }

    private static func scan(
        _ trivia: Trivia,
        startingAt start: AbsolutePosition,
        in file: LintFile,
        directives: inout [Directive],
        invalid: inout [InvalidDirective]
    ) {
        var position = start
        for piece in trivia {
            defer { position = position.advanced(by: piece.sourceLength.utf8Length) }
            guard case let .lineComment(text) = piece else { continue }
            let body = text.dropFirst(2).drop { $0 == " " }
            guard body.hasPrefix(prefix) else { continue }
            let location = file.location(of: position)
            if let directive = directive(from: String(body.dropFirst(prefix.count)), line: location.line, column: location.column) {
                directives.append(directive)
            } else {
                invalid.append(InvalidDirective(text: text, line: location.line, column: location.column))
            }
        }
    }

    static func directive(from text: String, line: Int, column: Int) -> Directive? {
        let (command, remainder) = split(text, at: " ")
        guard let kind = Directive.Kind(rawValue: command) else { return nil }
        let (idsText, reasonText) = split(remainder, at: " - ")
        let ids = idsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { RuleID($0) }
        guard !ids.isEmpty, !ids.contains(where: { $0.rawValue.contains(" ") }) else { return nil }
        let reason = reasonText.trimmingCharacters(in: .whitespaces)
        return Directive(kind: kind, ruleIDs: ids, reason: reason.isEmpty ? nil : reason, line: line, column: column)
    }

    private static func split(_ text: String, at separator: String) -> (String, String) {
        guard let range = text.range(of: separator) else {
            return (text.trimmingCharacters(in: .whitespaces), "")
        }
        return (String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces), String(text[range.upperBound...]))
    }
}
