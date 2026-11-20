import LintableKit

public enum ConfigurationError: Error, CustomStringConvertible, Equatable {
    case notFound(searchedFrom: String)
    case unreadable(path: String)
    case invalidYAML(String)
    case notAMapping(key: String)
    case unknownKey(String)
    case invalidValue(key: String, expected: String)
    case unknownRule(RuleID)
    case unknownOptions(rule: RuleID, keys: [String])
    case invalidOptions(rule: RuleID, message: String)
    case invalidSeverity(rule: RuleID, value: String)

    public var description: String {
        switch self {
        case let .notFound(directory):
            "No .lintable.yml found in \(directory) or its parents. Run `lintable init` to create one."
        case let .unreadable(path):
            "Can't read the config at \(path)."
        case let .invalidYAML(message):
            "The config isn't valid YAML: \(message)"
        case let .notAMapping(key):
            key.isEmpty ? "The config must be a mapping of keys to values." : "`\(key)` must be a mapping."
        case let .unknownKey(key):
            "Unknown config key `\(key)`. Known keys: included, excluded, baseline, require_reasons, release_condition, rules."
        case let .invalidValue(key, expected):
            "`\(key)` must be \(expected)."
        case let .unknownRule(id):
            "No loaded rule is called `\(id)`. Run `lintable rules` to list them."
        case let .unknownOptions(rule, keys):
            "Rule `\(rule)` has no option \(keys.map { "`\($0)`" }.joined(separator: ", "))."
        case let .invalidOptions(rule, message):
            "Rule `\(rule)`'s options are invalid: \(message)."
        case let .invalidSeverity(rule, value):
            "Rule `\(rule)` has severity `\(value)`; use `error` or `warning`."
        }
    }
}
