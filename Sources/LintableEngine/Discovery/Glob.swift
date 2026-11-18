import Foundation

public struct Glob: Sendable {
    public let pattern: String
    private let expression: NSRegularExpression?

    public init(_ pattern: String) {
        self.pattern = pattern
        expression = try? NSRegularExpression(pattern: Self.regularExpression(for: pattern))
    }

    public func matches(_ path: String) -> Bool {
        guard let expression else { return false }
        let range = NSRange(path.startIndex ..< path.endIndex, in: path)
        return expression.firstMatch(in: path, range: range) != nil
    }

    public func matchesPathOrAncestor(_ relativePath: String) -> Bool {
        if matches(relativePath) {
            return true
        }
        var components = relativePath.split(separator: "/").map(String.init)
        while components.count > 1 {
            components.removeLast()
            if matches(components.joined(separator: "/")) {
                return true
            }
        }
        return false
    }

    private static func regularExpression(for pattern: String) -> String {
        var trimmed = pattern
        while trimmed.hasPrefix("./") {
            trimmed.removeFirst(2)
        }
        while trimmed.hasSuffix("/"), trimmed.count > 1 {
            trimmed.removeLast()
        }
        var result = "^"
        var characters = Array(trimmed)[...]
        while let character = characters.first {
            characters = characters.dropFirst()
            switch character {
            case "*":
                if characters.first == "*" {
                    characters = characters.dropFirst()
                    if characters.first == "/" {
                        characters = characters.dropFirst()
                        result += "(?:.*/)?"
                    } else {
                        result += ".*"
                    }
                } else {
                    result += "[^/]*"
                }
            case "?":
                result += "[^/]"
            default:
                result += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        return result + "$"
    }
}
