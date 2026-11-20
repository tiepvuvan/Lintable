import Foundation
import LintableKit

public enum ReleaseGate {
    public static let fileName = "LintableReleaseGate.swift"

    public static func source(blocking violations: [ReportedViolation], condition: String?) -> String {
        guard let condition, !violations.isEmpty else { return "" }
        let byRule = Dictionary(grouping: violations, by: \.ruleID)
        var lines = ["#if \(condition)"]
        for id in byRule.keys.sorted() {
            let ruleViolations = (byRule[id] ?? []).sorted()
            guard let first = ruleViolations.first else { continue }
            let count = ruleViolations.count == 1 ? "1 \(id) warning stops" : "\(ruleViolations.count) \(id) warnings stop"
            let message = "\(count) release builds. The first is \(first.relativePath):\(first.line): \(first.message)"
            lines.append("#error(\(literal(message)))")
        }
        lines.append("#endif")
        return lines.joined(separator: "\n") + "\n"
    }

    public static func write(_ source: String, to path: String) throws {
        let data = Data(source.utf8)
        if FileManager.default.contents(atPath: path) == data {
            return
        }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func literal(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n", "\r", "\r\n", "\t":
                escaped += " "
            default:
                escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }
}
