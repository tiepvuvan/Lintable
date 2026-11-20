import Foundation
import LintableKit
import Yams

public struct Configuration: Sendable {
    public static let fileName = ".lintable.yml"
    public static let defaultBaselineName = ".lintable-baseline.json"

    public let file: URL?
    public let rootDirectory: URL
    public let included: [String]
    public let excluded: [String]
    public let baselinePath: String?
    public let requireReasons: Bool
    public let releaseCondition: String?
    public let rules: [ConfiguredRule]
    public let engineSeverities: [RuleID: Severity]
    public let fingerprint: String

    public var enabledRuleIDs: Set<RuleID> {
        Set(rules.map(\.id))
    }

    public var hasCatalogRules: Bool {
        rules.contains { $0.fileKind == .stringCatalog }
    }

    public func severity(ofEngineRule id: RuleID) -> Severity {
        engineSeverities[id] ?? .warning
    }

    public var baselineURL: URL? {
        baselinePath.map { FileDiscovery.resolve($0, against: rootDirectory) }
    }

    public static func find(startingAt directory: URL, fileManager: FileManager = .default) -> URL? {
        var current = directory.standardizedFileURL
        while true {
            let candidate = current.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    public static func load(from url: URL, registry: RuleRegistry) throws -> Configuration {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw ConfigurationError.unreadable(path: url.path)
        }
        return try parse(
            yaml: String(decoding: data, as: UTF8.self),
            rootDirectory: url.deletingLastPathComponent(),
            registry: registry,
            file: url
        )
    }

    public static func parse(yaml: String, rootDirectory: URL, registry: RuleRegistry, file: URL? = nil) throws -> Configuration {
        let loaded: Any?
        do {
            loaded = try Yams.load(yaml: yaml)
        } catch {
            throw ConfigurationError.invalidYAML(String(describing: error))
        }
        let mapping: [String: Any]
        if loaded == nil {
            mapping = [:]
        } else if let dictionary = loaded.flatMap(stringKeyed) {
            mapping = dictionary
        } else {
            throw ConfigurationError.notAMapping(key: "")
        }
        if let unknown = mapping.keys.sorted().first(where: { !knownKeys.contains($0) }) {
            throw ConfigurationError.unknownKey(unknown)
        }
        let included = try stringList(mapping["included"], key: "included")
        let excluded = try stringList(mapping["excluded"], key: "excluded")
        let baseline = try optionalString(mapping["baseline"], key: "baseline")
        let requireReasons = try bool(mapping["require_reasons"], key: "require_reasons", default: true)
        let releaseCondition = try compilationCondition(mapping["release_condition"], key: "release_condition")
        let (rules, engineSeverities) = try parseRules(mapping["rules"], registry: registry)
        let fingerprintParts = [
            included.joined(separator: ","),
            excluded.joined(separator: ","),
            baseline ?? "",
            String(requireReasons),
            releaseCondition ?? "",
            rules.map { rule in
                "\(rule.id)=\(rule.severity.rawValue)/\(rule.releaseSeverity?.rawValue ?? "")\(rule.optionsFingerprint)"
            }.joined(separator: ";"),
            engineSeverities.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.rawValue)" }.joined(separator: ";"),
        ]
        return Configuration(
            file: file,
            rootDirectory: rootDirectory.standardizedFileURL,
            included: included,
            excluded: excluded,
            baselinePath: baseline,
            requireReasons: requireReasons,
            releaseCondition: releaseCondition,
            rules: rules,
            engineSeverities: engineSeverities,
            fingerprint: StableHash.hex(of: fingerprintParts.joined(separator: "\n"))
        )
    }

    private static func parseRules(_ value: Any?, registry: RuleRegistry) throws -> ([ConfiguredRule], [RuleID: Severity]) {
        guard let value else { return ([], [:]) }
        guard let rules = stringKeyed(value) else {
            throw ConfigurationError.notAMapping(key: "rules")
        }
        var configured: [ConfiguredRule] = []
        var engineSeverities: [RuleID: Severity] = [:]
        for name in rules.keys.sorted() {
            let id = RuleID(name)
            var options: [String: Any]
            if let entry = rules[name], !(entry is NSNull) {
                guard let dictionary = stringKeyed(entry) else {
                    throw ConfigurationError.notAMapping(key: "rules.\(name)")
                }
                options = dictionary
            } else {
                options = [:]
            }
            var severity: Severity?
            if let rawSeverity = options.removeValue(forKey: "severity") {
                guard let text = rawSeverity as? String, let parsed = Severity(rawValue: text) else {
                    throw ConfigurationError.invalidSeverity(rule: id, value: String(describing: rawSeverity))
                }
                severity = parsed
            }
            if EngineRules.ids.contains(id) {
                guard options.isEmpty else {
                    throw ConfigurationError.unknownOptions(rule: id, keys: options.keys.sorted())
                }
                engineSeverities[id] = severity ?? .warning
                continue
            }
            var releaseSeverity: Severity?
            if let rawReleaseSeverity = options.removeValue(forKey: "release_severity") {
                guard let text = rawReleaseSeverity as? String, let parsed = Severity(rawValue: text) else {
                    throw ConfigurationError.invalidSeverity(rule: id, value: String(describing: rawReleaseSeverity))
                }
                releaseSeverity = parsed
            }
            configured.append(try registry.makeRule(id, options: options, severity: severity, releaseSeverity: releaseSeverity))
        }
        return (configured, engineSeverities)
    }

    static let knownKeys: Set<String> = ["included", "excluded", "baseline", "require_reasons", "release_condition", "rules"]

    private static func compilationCondition(_ value: Any?, key: String) throws -> String? {
        guard let value else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_!&|() "))
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces),
              !text.isEmpty,
              text.unicodeScalars.allSatisfy(allowed.contains)
        else {
            throw ConfigurationError.invalidValue(key: key, expected: "a compilation condition such as `!DEBUG`")
        }
        return text
    }

    private static func stringKeyed(_ value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? [AnyHashable: Any] {
            return Dictionary(uniqueKeysWithValues: dictionary.map { (String(describing: $0.key), $0.value) })
        }
        return nil
    }

    private static func stringList(_ value: Any?, key: String) throws -> [String] {
        guard let value else { return [] }
        if let list = value as? [Any] {
            return try list.map { element in
                guard let text = element as? String else {
                    throw ConfigurationError.invalidValue(key: key, expected: "a list of paths")
                }
                return text
            }
        }
        if let text = value as? String {
            return [text]
        }
        throw ConfigurationError.invalidValue(key: key, expected: "a list of paths")
    }

    private static func optionalString(_ value: Any?, key: String) throws -> String? {
        guard let value else { return nil }
        guard let text = value as? String else {
            throw ConfigurationError.invalidValue(key: key, expected: "a path")
        }
        return text
    }

    private static func bool(_ value: Any?, key: String, default defaultValue: Bool) throws -> Bool {
        guard let value else { return defaultValue }
        guard let flag = value as? Bool else {
            throw ConfigurationError.invalidValue(key: key, expected: "true or false")
        }
        return flag
    }
}
