import LintableEngine
import LintableKit
import Testing

public func assertLint<R: Rule>(
    _ rule: R.Type,
    options: String? = nil,
    _ source: String,
    messages: [String: String] = [:],
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    assertViolations(
        of: RuleSubject(pack: SingleRulePack<R>.self, id: R.description.id, fileName: "Example.swift"),
        options: options,
        source: source,
        messages: messages,
        sourceLocation: sourceLocation
    )
}

public func assertCatalogLint<R: CatalogRule>(
    _ rule: R.Type,
    options: String? = nil,
    _ source: String,
    messages: [String: String] = [:],
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    assertViolations(
        of: RuleSubject(pack: SingleCatalogRulePack<R>.self, id: R.description.id, fileName: "Example.xcstrings"),
        options: options,
        source: source,
        messages: messages,
        sourceLocation: sourceLocation
    )
}

func assertViolations(
    of subject: RuleSubject,
    options: String?,
    source: String,
    messages: [String: String],
    sourceLocation: Testing.SourceLocation
) {
    let parsed = Example(source).parse()
    let outcome = RuleHarness.run(subject, options: options, source: parsed.source)
    let id = subject.id
    if let setupError = outcome.setupError {
        Issue.record(Comment(rawValue: "Couldn't run `\(id)`: \(setupError)"), sourceLocation: sourceLocation)
        return
    }
    var expected: [LineColumn: String] = [:]
    for marker in parsed.markers {
        expected[outcome.lines.location(ofUTF8Offset: marker.utf8Offset)] = marker.name
    }
    let actual = Dictionary(
        outcome.ruleViolations.map { (LineColumn(line: $0.line, column: $0.column), $0) },
        uniquingKeysWith: { first, _ in first }
    )
    for (location, marker) in expected.sorted(by: { $0.key < $1.key }) {
        guard let violation = actual[location] else {
            let text = [
                "Expected a violation at \(marker) (\(location.line):\(location.column)), but there is none.",
                excerpt(outcome.lines, location),
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
            Comment(rawValue: "Unexpected violation at \(location.line):\(location.column): \(violation.message)\n\(excerpt(outcome.lines, location))"),
            sourceLocation: sourceLocation
        )
    }
}

func excerpt(_ lines: LineMap, _ location: LineColumn) -> String {
    let line = lines.source.split(separator: "\n", omittingEmptySubsequences: false)
    guard location.line >= 1, location.line <= line.count else { return "" }
    let text = String(line[location.line - 1])
    let caret = String(repeating: " ", count: max(0, location.column - 1)) + "^"
    return "    \(text)\n    \(caret)"
}

private func describe(_ violations: [ReportedViolation]) -> String {
    violations.isEmpty ? "nothing" : violations.map { "\($0.line):\($0.column)" }.joined(separator: ", ")
}
