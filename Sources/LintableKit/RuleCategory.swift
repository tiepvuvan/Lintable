public struct RuleCategory: Hashable, Sendable, Codable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static let layout = RuleCategory(id: "layout", name: "UIKit and AppKit layout")
    public static let localization = RuleCategory(id: "localization", name: "Localization")
    public static let accessibility = RuleCategory(id: "accessibility", name: "Accessibility")
    public static let engine = RuleCategory(id: "engine", name: "Lintable")
}
