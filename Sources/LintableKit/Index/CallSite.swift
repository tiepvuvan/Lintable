import SwiftSyntax

public struct CallSite: Sendable, Hashable {
    public enum Receiver: Sendable, Hashable {
        case implicit
        case explicitSelf
        case other(String)
    }

    public let baseName: String
    public let argumentLabels: [String?]
    public let hasTrailingClosure: Bool
    public let additionalTrailingClosureLabels: [String]
    public let receiver: Receiver
    public let node: Syntax

    public func matches(_ signature: FunctionSignature) -> Bool {
        guard baseName == signature.baseName else { return false }
        var remaining = signature.parameters[...]
        var isInsideVariadic = false
        func consume(_ label: String?) -> Bool {
            if isInsideVariadic, label == nil {
                return true
            }
            while let parameter = remaining.first {
                remaining = remaining.dropFirst()
                if parameter.label == label {
                    isInsideVariadic = parameter.isVariadic
                    return true
                }
                if !parameter.hasDefaultValue {
                    return false
                }
            }
            return false
        }
        for label in argumentLabels where !consume(label) {
            return false
        }
        isInsideVariadic = false
        if hasTrailingClosure {
            while let parameter = remaining.first, parameter.hasDefaultValue, remaining.count > 1 {
                remaining = remaining.dropFirst()
            }
            guard !remaining.isEmpty else { return false }
            remaining = remaining.dropFirst()
        }
        for label in additionalTrailingClosureLabels where !consume(label) {
            return false
        }
        return remaining.allSatisfy(\.hasDefaultValue)
    }
}

public struct Reference: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case selector
        case value
    }

    public let kind: Kind
    public let baseName: String
    public let argumentLabels: [String?]?
    public let node: Syntax

    public func matches(_ signature: FunctionSignature) -> Bool {
        guard baseName == signature.baseName else { return false }
        guard let argumentLabels else { return true }
        return argumentLabels == signature.labels
    }
}
