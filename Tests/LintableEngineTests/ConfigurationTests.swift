import Foundation
import LintableEngine
import LintableKit
import Testing

@Suite struct ConfigurationTests {
    @Test func readsEveryKey() throws {
        let config = try configuration("""
        included:
          - Sources
        excluded: "**/Tests/**"
        baseline: .lintable-baseline.json
        require_reasons: false
        rules:
          forbidden_name:
            severity: warning
            names: [bad, worse]
          superfluous_directive:
            severity: error
        """)
        #expect(config.included == ["Sources"])
        #expect(config.excluded == ["**/Tests/**"])
        #expect(config.baselinePath == ".lintable-baseline.json")
        #expect(config.requireReasons == false)
        #expect(config.rules.map(\.id) == ["forbidden_name"])
        #expect(config.rules.first?.severity == .warning)
        #expect(config.severity(ofEngineRule: EngineRules.superfluousDirective) == .error)
        #expect(config.severity(ofEngineRule: EngineRules.unknownRule) == .warning)
    }

    @Test func aRuleWithNoValueUsesItsDefaults() throws {
        let config = try configuration("rules:\n  forbidden_name:")
        #expect(config.rules.first?.severity == .error)
        #expect(config.rules.first?.optionsFingerprint.contains("\"names\":[\"forbidden\"]") == true)
    }

    @Test func emptyConfigEnablesNothing() throws {
        #expect(try configuration("").rules.isEmpty)
    }

    @Test func optionsChangeWhatTheRuleReports() throws {
        let violations = try lint("let a = bad\nlet b = forbidden", config: "rules:\n  forbidden_name:\n    names: [bad]")
        #expect(violations.map(\.line) == [1])
    }

    @Test(arguments: [
        ("unknown: 1", ConfigurationError.unknownKey("unknown")),
        ("rules:\n  missing_rule:", ConfigurationError.unknownRule("missing_rule")),
        ("rules:\n  forbidden_name:\n    severity: fatal", ConfigurationError.invalidSeverity(rule: "forbidden_name", value: "fatal")),
        ("rules:\n  forbidden_name:\n    colour: red", ConfigurationError.unknownOptions(rule: "forbidden_name", keys: ["colour"])),
        ("rules: [forbidden_name]", ConfigurationError.notAMapping(key: "rules")),
        ("require_reasons: maybe", ConfigurationError.invalidValue(key: "require_reasons", expected: "true or false")),
        ("- a\n- b", ConfigurationError.notAMapping(key: "")),
        ("rules:\n  superfluous_directive:\n    extra: 1", ConfigurationError.unknownOptions(rule: "superfluous_directive", keys: ["extra"])),
    ])
    func invalidConfigs(yaml: String, expected: ConfigurationError) {
        #expect(throws: expected) {
            try configuration(yaml)
        }
    }

    @Test func wrongOptionTypeNamesTheOption() {
        #expect {
            try configuration("rules:\n  forbidden_name:\n    report_calls: often")
        } throws: { error in
            guard case let .invalidOptions(rule, message) = error as? ConfigurationError else { return false }
            return rule == "forbidden_name" && message.contains("report_calls")
        }
    }

    @Test func fingerprintFollowsTheConfig() throws {
        let first = try configuration("rules:\n  forbidden_name:")
        let same = try configuration("rules:\n  forbidden_name:\n    names: [forbidden]")
        let different = try configuration("rules:\n  forbidden_name:\n    names: [other]")
        #expect(first.fingerprint == same.fingerprint)
        #expect(first.fingerprint != different.fingerprint)
    }

    @Test func findsTheNearestConfigUpward() throws {
        let directory = try TemporaryDirectory()
        let config = try directory.write(".lintable.yml", "rules: {}")
        try directory.write("Sources/Deep/A.swift", "")
        let found = Configuration.find(startingAt: directory.url.appendingPathComponent("Sources/Deep"))
        #expect(found?.standardizedFileURL.path == config.standardizedFileURL.path)
    }
}

@Suite struct RegistryTests {
    @Test func duplicateIDsAreRefused() {
        #expect(throws: RegistryError.duplicateRuleID("forbidden_name")) {
            try RuleRegistry(packs: [TestRules.self, TestRules.self])
        }
    }

    @Test func listsRulesAndDefaults() throws {
        let registry = try registry()
        #expect(registry.ruleIDs == ["forbidden_name"])
        let defaults = try registry.defaultOptions(of: "forbidden_name")
        #expect(defaults["names"] as? [String] == ["forbidden"])
        #expect(defaults["report_calls"] as? Bool == true)
    }
}
