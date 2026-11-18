import Foundation
import LintableKit

public struct SARIFReporter: Reporter {
    public static let name = "sarif"

    public init() {}

    public func render(_ result: LintResult) -> String {
        let rules: [[String: Any]] = result.rules.map { rule in
            [
                "id": rule.id.rawValue,
                "name": rule.name,
                "shortDescription": ["text": rule.summary],
                "fullDescription": ["text": rule.rationale],
                "helpUri": rule.documentationURL,
                "defaultConfiguration": ["level": level(rule.defaultSeverity)],
            ]
        }
        let results: [[String: Any]] = result.violations.map { violation in
            [
                "ruleId": violation.ruleID.rawValue,
                "level": level(violation.severity),
                "message": ["text": violation.message],
                "locations": [
                    [
                        "physicalLocation": [
                            "artifactLocation": ["uri": violation.relativePath],
                            "region": ["startLine": violation.line, "startColumn": violation.column],
                        ],
                    ],
                ],
            ]
        }
        let document: [String: Any] = [
            "version": "2.1.0",
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "runs": [
                [
                    "tool": [
                        "driver": [
                            "name": "Lintable",
                            "version": LintableVersion.current,
                            "informationUri": "https://github.com/tiepvuvan/Lintable",
                            "rules": rules,
                        ],
                    ],
                    "results": results,
                ],
            ],
        ]
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? JSONSerialization.data(withJSONObject: document, options: options))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private func level(_ severity: Severity) -> String {
        severity == .error ? "error" : "warning"
    }
}
