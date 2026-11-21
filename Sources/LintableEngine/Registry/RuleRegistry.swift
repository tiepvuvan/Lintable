import Foundation
import LintableKit

public struct RuleRegistry: Sendable {
    enum RegisteredRule: Sendable {
        case swift(any Rule.Type)
        case stringCatalog(any CatalogRule.Type)

        var description: RuleDescription {
            switch self {
            case let .swift(type):
                type.description
            case let .stringCatalog(type):
                type.description
            }
        }
    }

    public let packs: [any RulePack.Type]
    private let ruleTypes: [RuleID: RegisteredRule]

    public init(packs: [any RulePack.Type]) throws {
        var ruleTypes: [RuleID: RegisteredRule] = [:]
        for pack in packs {
            let registered = pack.rules.map(RegisteredRule.swift) + pack.catalogRules.map(RegisteredRule.stringCatalog)
            for rule in registered {
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
        switch ruleTypes[id] {
        case let .swift(type):
            try Self.defaultOptions(of: type)
        case let .stringCatalog(type):
            try Self.defaultOptions(ofCatalogRule: type)
        case nil:
            throw ConfigurationError.unknownRule(id)
        }
    }

    public func makeRule(
        _ id: RuleID,
        options: [String: Any] = [:],
        severity: Severity? = nil,
        releaseSeverity: Severity? = nil
    ) throws -> ConfiguredRule {
        switch ruleTypes[id] {
        case let .swift(type):
            try Self.makeSwiftRule(type, options: options, severity: severity, releaseSeverity: releaseSeverity)
        case let .stringCatalog(type):
            try Self.makeCatalogRule(type, options: options, severity: severity, releaseSeverity: releaseSeverity)
        case nil:
            throw ConfigurationError.unknownRule(id)
        }
    }

    private static func makeSwiftRule<R: Rule>(
        _ type: R.Type,
        options: [String: Any],
        severity: Severity?,
        releaseSeverity: Severity?
    ) throws -> ConfiguredRule {
        let decoded = try decodeOptions(R.Options.self, of: R.description.id, from: options)
        let rule = R(options: decoded)
        return ConfiguredRule(
            id: R.description.id,
            description: R.description,
            severity: severity ?? R.description.defaultSeverity,
            releaseSeverity: releaseSeverity,
            optionsFingerprint: fingerprint(of: decoded),
            body: .swift { rule.check($0) }
        )
    }

    private static func makeCatalogRule<R: CatalogRule>(
        _ type: R.Type,
        options: [String: Any],
        severity: Severity?,
        releaseSeverity: Severity?
    ) throws -> ConfiguredRule {
        let decoded = try decodeOptions(R.Options.self, of: R.description.id, from: options)
        let rule = R(options: decoded)
        return ConfiguredRule(
            id: R.description.id,
            description: R.description,
            severity: severity ?? R.description.defaultSeverity,
            releaseSeverity: releaseSeverity,
            optionsFingerprint: fingerprint(of: decoded),
            referencedCatalogPaths: rule.referencedCatalogPaths,
            body: .stringCatalog { rule.check($0, in: $1) }
        )
    }

    private static func fingerprint(of options: some RuleOptions) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return (try? encoder.encode(options)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    private static func defaultOptions<R: Rule>(of _: R.Type) throws -> [String: Any] {
        try defaultOptions(R.Options.self)
    }

    private static func defaultOptions<R: CatalogRule>(ofCatalogRule _: R.Type) throws -> [String: Any] {
        try defaultOptions(R.Options.self)
    }

    private static func defaultOptions<O: RuleOptions>(_ type: O.Type) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(O())
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func decodeOptions<O: RuleOptions>(_ type: O.Type, of id: RuleID, from options: [String: Any]) throws -> O {
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
            return try decoder.decode(type, from: data)
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
