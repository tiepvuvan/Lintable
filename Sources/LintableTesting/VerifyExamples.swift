import LintableKit
import SwiftSyntax
import Testing

public func verifyExamples<R: Rule>(of rule: R.Type, sourceLocation: Testing.SourceLocation = #_sourceLocation) {
    let description = R.description
    verifyMarkers(of: description, sourceLocation: sourceLocation) { example, parsed, label in
        checkSyntax(parsed.source, label: label, id: description.id, sourceLocation: sourceLocation)
        assertLint(R.self, options: example.options, example.source, sourceLocation: sourceLocation)
    }
    for (index, example) in description.triggeringExamples.enumerated() {
        let parsed = example.parse()
        if !parsed.markers.isEmpty {
            checkSuppression(of: example, parsed: parsed, index: index, sourceLocation: sourceLocation, rule: R.self)
        }
    }
}

public func verifyExamples<R: CatalogRule>(of rule: R.Type, sourceLocation: Testing.SourceLocation = #_sourceLocation) {
    let description = R.description
    verifyMarkers(of: description, sourceLocation: sourceLocation) { example, parsed, label in
        do {
            _ = try StringCatalog(path: "Example.xcstrings", source: parsed.source)
        } catch {
            Issue.record(Comment(rawValue: "\(label) of `\(description.id)` isn't a String Catalog: \(error)."), sourceLocation: sourceLocation)
        }
        assertCatalogLint(R.self, options: example.options, example.source, sourceLocation: sourceLocation)
    }
}

private func verifyMarkers(
    of description: RuleDescription,
    sourceLocation: Testing.SourceLocation,
    check: (Example, ParsedExample, String) -> Void
) {
    if description.triggeringExamples.isEmpty {
        Issue.record(Comment(rawValue: "`\(description.id)` has no triggering examples."), sourceLocation: sourceLocation)
    }
    for (index, example) in description.triggeringExamples.enumerated() {
        let parsed = example.parse()
        if parsed.markers.isEmpty {
            Issue.record(Comment(rawValue: "Triggering example \(index + 1) of `\(description.id)` has no markers."), sourceLocation: sourceLocation)
            continue
        }
        check(example, parsed, "Triggering example \(index + 1)")
    }
    for (index, example) in description.nonTriggeringExamples.enumerated() {
        let parsed = example.parse()
        if !parsed.markers.isEmpty {
            Issue.record(Comment(rawValue: "Non-triggering example \(index + 1) of `\(description.id)` has markers."), sourceLocation: sourceLocation)
        }
        check(Example(parsed.source, options: example.options), parsed, "Non-triggering example \(index + 1)")
    }
}

private func checkSyntax(_ source: String, label: String, id: RuleID, sourceLocation: Testing.SourceLocation) {
    if LintFile(path: "Example.swift", source: source).hasSyntaxErrors {
        Issue.record(Comment(rawValue: "\(label) of `\(id)` doesn't parse."), sourceLocation: sourceLocation)
    }
}

private func checkSuppression<R: Rule>(
    of example: Example,
    parsed: ParsedExample,
    index: Int,
    sourceLocation: Testing.SourceLocation,
    rule _: R.Type
) {
    let file = LintFile(path: "Example.swift", source: parsed.source)
    let markedLines = Set(parsed.markers.map { file.location(of: AbsolutePosition(utf8Offset: $0.utf8Offset)).line })
    var lines: [String] = []
    for (number, line) in parsed.source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        if markedLines.contains(number + 1) {
            let indentation = line.prefix { $0 == " " || $0 == "\t" }
            lines.append("\(indentation)// lintable:disable:next \(R.description.id) - verifying the example")
        }
        lines.append(String(line))
    }
    let outcome = RuleHarness.run(
        RuleSubject(pack: SingleRulePack<R>.self, id: R.description.id, fileName: "Example.swift"),
        options: example.options,
        source: lines.joined(separator: "\n")
    )
    let remaining = outcome.ruleViolations + outcome.engineViolations
    if !remaining.isEmpty {
        let details = remaining.map { "\($0.line):\($0.column) \($0.ruleID): \($0.message)" }.joined(separator: "\n  ")
        Issue.record(
            Comment(rawValue: "Triggering example \(index + 1) of `\(R.description.id)` still reports after `disable:next` on each marked line:\n  \(details)"),
            sourceLocation: sourceLocation
        )
    }
}
