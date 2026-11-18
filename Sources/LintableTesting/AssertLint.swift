import LintableEngine
import LintableKit
import SwiftSyntax
import Testing

public func assertLint<R: Rule>(
    _ rule: R.Type,
    options: String? = nil,
    _ source: String,
    messages: [String: String] = [:],
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    let parsed = Example(source).parse()
    let outcome = RuleHarness<R>.run(options: options, source: parsed.source)
    if let setupError = outcome.setupError {
        Issue.record(Comment(rawValue: "Couldn't run `\(R.description.id)`: \(setupError)"), sourceLocation: sourceLocation)
        return
    }
    var expected: [LineColumn: String] = [:]
    for marker in parsed.markers {
        expected[outcome.file.location(of: AbsolutePosition(utf8Offset: marker.utf8Offset))] = marker.name
    }
    let actual = Dictionary(
        outcome.ruleViolations.map { (LineColumn(line: $0.line, column: $0.column), $0) },
        uniquingKeysWith: { first, _ in first }
    )
    for (location, marker) in expected.sorted(by: { $0.key < $1.key }) {
        guard let violation = actual[location] else {
            let text = [
                "Expected a violation at \(marker) (\(location.line):\(location.column)), but there is none.",
                excerpt(outcome.file, location),
                "Reported: \(describe(outcome.ruleViolations))",
            ].joined(separator: "\n")
            Issue.record(Comment(rawValue: text), sourceLocation: sourceLocation)
            continue
        }
        if let message = messages[marker], message != violation.message {
            Issue.record(
                Comment(rawValue: "The violation at \(marker) says:\n  \(violation.message)\nExpected:\n  \(message)"),
                sourceLocation: sourceLocation
            )
        }
    }
    for (location, violation) in actual.sorted(by: { $0.key < $1.key }) where expected[location] == nil {
        Issue.record(
            Comment(rawValue: "Unexpected violation at \(location.line):\(location.column): \(violation.message)\n\(excerpt(outcome.file, location))"),
            sourceLocation: sourceLocation
        )
    }
}

func excerpt(_ file: LintFile, _ location: LineColumn) -> String {
    let line = file.source.split(separator: "\n", omittingEmptySubsequences: false)
    guard location.line >= 1, location.line <= line.count else { return "" }
    let text = String(line[location.line - 1])
    let caret = String(repeating: " ", count: max(0, location.column - 1)) + "^"
    return "    \(text)\n    \(caret)"
}

private func describe(_ violations: [ReportedViolation]) -> String {
    violations.isEmpty ? "nothing" : violations.map { "\($0.line):\($0.column)" }.joined(separator: ", ")
}
