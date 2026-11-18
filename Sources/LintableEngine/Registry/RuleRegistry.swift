import Foundation
import LintableKit

public struct RuleRegistry: Sendable {
    public let packs: [any RulePack.Type]
    private let ruleTypes: [RuleID: any Rule.Type]

    public init(packs: [any RulePack.Type]) throws {
        var ruleTypes: [RuleID: any Rule.Type] = [:]
        for pack in packs {
            for rule in pack.rules {
                let id = rule.description.id
                guard id.isWellFormed else {
                    throw RegistryError.malformedRuleID(id, pack: pack.name)
                }
                guard !EngineRules.ids.contains(id) else {
                    throw RegistryError.reservedRuleID(id, pack: pack.name)
                }
                guard ruleTypes[id] == nil else {
                    throw RegistryError.duplicateRuleID(id)
                }
                ruleTypes[id] = rule
            }
        }
        self.packs = packs
        self.ruleTypes = ruleTypes
    }

    public var ruleIDs: [RuleID] {
        ruleTypes.keys.sorted()
    }

    public var descriptions: [RuleDescription] {
        ruleIDs.compactMap { ruleTypes[$0]?.description }
    }

    public func contains(_ id: RuleID) -> Bool {
        ruleTypes[id] != nil
    }

    public func description(of id: RuleID) -> RuleDescription? {
        ruleTypes[id]?.description ?? EngineRules.descriptions.first { $0.id == id }
    }

    public var fingerprint: String {
        let packs = packs.map { "\($0.name)@\($0.version)" }.sorted()
        return StableHash.hex(of: (packs + ruleIDs.map(\.rawValue)).joined(separator: "\n"))
    }

    public func defaultOptions(of id: RuleID) throws -> [String: Any] {
        guard let ruleType = ruleTypes[id] else {
            throw ConfigurationError.unknownRule(id)
        }
        return try Self.defaultOptions(ruleType)
    }

    public func makeRule(_ id: RuleID, options: [String: Any] = [:], severity: Severity? = nil) throws -> ConfiguredRule {
        guard let ruleType = ruleTypes[id] else {
            throw ConfigurationError.unknownRule(id)
        }
        return try Self.make(ruleType, options: options, severity: severity)
    }

    private static func make<R: Rule>(_ type: R.Type, options: [String: Any], severity: Severity?) throws -> ConfiguredRule {
        let decoded = try decodeOptions(type, from: options)
        let rule = R(options: decoded)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let fingerprint = (try? encoder.encode(decoded)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return ConfiguredRule(
            id: R.description.id,
            description: R.description,
            severity: severity ?? R.description.defaultSeverity,
            optionsFingerprint: fingerprint,
            body: { rule.check($0) }
        )
    }

    private static func defaultOptions<R: Rule>(_ type: R.Type) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(R.Options())
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func decodeOptions<R: Rule>(_ type: R.Type, from options: [String: Any]) throws -> R.Options {
        let id = R.description.id
        let defaults = try defaultOptions(type)
        let unknown = Set(options.keys).subtracting(defaults.keys).sorted()
        guard unknown.isEmpty else {
            throw ConfigurationError.unknownOptions(rule: id, keys: unknown)
        }
        let merged = defaults.merging(options) { $1 }
        do {
            let data = try JSONSerialization.data(withJSONObject: merged)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(R.Options.self, from: data)
        } catch let error as DecodingError {
            throw ConfigurationError.invalidOptions(rule: id, message: Self.describe(error))
        }
    }

    private static func snakeCase(_ key: String) -> String {
        var result = ""
        for character in key {
            if character.isUppercase {
                result += "_" + character.lowercased()
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case let .typeMismatch(type, context), let .valueNotFound(type, context):
            let key = context.codingPath.map { snakeCase($0.stringValue) }.joined(separator: ".")
            return "`\(key)` should be \(type)"
        case let .dataCorrupted(context):
            return context.debugDescription
        case let .keyNotFound(key, _):
            return "`\(snakeCase(key.stringValue))` is missing"
        @unknown default:
            return "the options can't be read"
        }
    }
}

public enum RegistryError: Error, CustomStringConvertible, Equatable {
    case malformedRuleID(RuleID, pack: String)
    case reservedRuleID(RuleID, pack: String)
    case duplicateRuleID(RuleID)

    public var description: String {
        switch self {
        case let .malformedRuleID(id, pack):
            "Rule `\(id)` in \(pack) isn't snake_case."
        case let .reservedRuleID(id, pack):
            "Rule `\(id)` in \(pack) uses an ID reserved for Lintable itself."
        case let .duplicateRuleID(id):
            "Two loaded rules share the ID `\(id)`."
        }
    }
}
