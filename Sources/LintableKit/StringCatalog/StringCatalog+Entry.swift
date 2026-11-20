import Foundation
import SwiftSyntax

public extension StringCatalog {
    struct Entry: Sendable {
        public let key: String
        public let position: AbsolutePosition
        public let comment: String?
        public let extractionState: String?
        public let shouldTranslate: Bool
        public let localizations: [Localization]

        init(_ member: JSONMember) {
            key = member.key
            position = member.position
            comment = member.value["comment"]?.string
            extractionState = member.value["extractionState"]?.string
            shouldTranslate = member.value["shouldTranslate"]?.bool ?? true
            localizations = (member.value["localizations"]?.members ?? []).map(Localization.init)
        }

        public var isStale: Bool {
            extractionState == "stale"
        }

        public var needsTranslation: Bool {
            shouldTranslate && !isStale && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public func localization(for language: String) -> Localization? {
            localizations.first { $0.language == language }
        }
    }

    struct Localization: Sendable {
        public let language: String
        public let position: AbsolutePosition
        public let content: Content

        init(_ member: JSONMember) {
            language = member.key
            position = member.position
            content = Content(member.value, position: member.position)
        }
    }
}
