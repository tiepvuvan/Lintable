import Foundation
import LintableKit

public enum RuleDocumentation {
    public static func page(for description: RuleDescription, defaults: [String: Any]) -> String {
        var sections: [String] = []
        sections.append("""
        # `\(description.id)`

        **\(description.name)** · \(description.category.name) · default severity: \(description.defaultSeverity.rawValue)

        \(description.summary)
        """)
        sections.append("## Rationale\n\n\(description.rationale)")
        if !defaults.isEmpty {
            var rows = ["| Option | Default | Meaning |", "|---|---|---|"]
            for key in defaults.keys.sorted() {
                let meaning = description.optionDescriptions[key] ?? ""
                rows.append("| `\(key)` | \(render(defaults[key])) | \(meaning) |")
            }
            sections.append("## Options\n\n" + rows.joined(separator: "\n"))
        }
        if !description.howToFix.isEmpty {
            sections.append("## How to fix\n\n\(description.howToFix)")
        }
        if !description.triggeringExamples.isEmpty {
            sections.append("## Reported\n\n" + description.triggeringExamples.map(render).joined(separator: "\n\n"))
        }
        if !description.nonTriggeringExamples.isEmpty {
            sections.append("## Not reported\n\n" + description.nonTriggeringExamples.map(render).joined(separator: "\n\n"))
        }
        return sections.joined(separator: "\n\n") + "\n"
    }

    public static func index(for descriptions: [RuleDescription]) -> String {
        var lines = ["# Rules", "", "| Rule | Category | Summary |", "|---|---|---|"]
        for description in descriptions.sorted(by: { $0.id < $1.id }) {
            lines.append("| [`\(description.id)`](\(description.id).md) | \(description.category.name) | \(description.summary) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func render(_ example: Example) -> String {
        var source = example.source
        for marker in Example.markerNames {
            source = source.replacingOccurrences(of: marker, with: "↓")
        }
        let code = "```swift\n\(source)\n```"
        guard let options = example.options else { return code }
        return "With these options:\n\n```yaml\n\(options)\n```\n\n\(code)"
    }

    private static func render(_ value: Any?) -> String {
        guard let value else { return "" }
        if let list = value as? [Any] {
            return list.isEmpty ? "none" : list.map { "`\(json($0))`" }.joined(separator: ", ")
        }
        return "`\(json(value))`"
    }

    private static func json(_ value: Any) -> String {
        let options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: options) else {
            return String(describing: value)
        }
        let text = String(decoding: data, as: UTF8.self)
        return text.count >= 2 && text.hasPrefix("\"") && text.hasSuffix("\"") ? String(text.dropFirst().dropLast()) : text
    }
}
