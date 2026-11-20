import SwiftSyntax

public extension StringCatalog {
    struct Content: Sendable {
        public let position: AbsolutePosition
        public let stringUnit: StringUnit?
        public let stringSet: StringSet?
        public let variations: [Variation]
        public let substitutions: [Substitution]

        init(_ value: JSONValue, position: AbsolutePosition) {
            self.position = position
            stringUnit = value.member("stringUnit").map(StringUnit.init)
            stringSet = value.member("stringSet").map(StringSet.init)
            variations = (value["variations"]?.members ?? []).map(Variation.init)
            substitutions = (value["substitutions"]?.members ?? []).map(Substitution.init)
        }

        init(text: String, position: AbsolutePosition) {
            self.position = position
            stringUnit = StringUnit(state: nil, value: text, position: position)
            stringSet = nil
            variations = []
            substitutions = []
        }

        public var units: [StringUnit] {
            var collected = [stringUnit, stringSet?.unit].compactMap(\.self)
            let nested = variations + substitutions.flatMap(\.variations)
            for variation in nested {
                for variationCase in variation.cases {
                    collected += variationCase.content.units
                }
            }
            return collected
        }

        public var referenceContent: Content {
            guard stringUnit == nil, stringSet == nil, let variation = variations.first else { return self }
            let preferred = variation.cases.first { $0.name == PluralCategory.other.rawValue } ?? variation.cases.first
            return preferred?.content.referenceContent ?? self
        }

        public var text: String {
            let reference = referenceContent
            return reference.stringUnit?.value ?? reference.stringSet?.unit.value ?? ""
        }

        public var showsNumber: Bool {
            FormatSpecifier.parse(text).contains(where: \.showsNumber)
        }

        public var pluralGroups: [PluralGroup] {
            var groups: [PluralGroup] = []
            for variation in variations {
                if variation.kind == "plural" {
                    groups.append(PluralGroup(position: variation.position, cases: variation.cases, substitution: nil))
                } else {
                    groups += variation.cases.flatMap(\.content.pluralGroups)
                }
            }
            for substitution in substitutions {
                for variation in substitution.variations where variation.kind == "plural" {
                    groups.append(PluralGroup(position: variation.position, cases: variation.cases, substitution: substitution))
                }
            }
            return groups
        }
    }

    struct StringUnit: Sendable, Equatable {
        public let state: String?
        public let value: String
        public let position: AbsolutePosition

        init(_ member: JSONMember) {
            state = member.value["state"]?.string
            value = member.value["value"]?.string ?? ""
            position = member.position
        }

        init(state: String?, value: String, position: AbsolutePosition) {
            self.state = state
            self.value = value
            self.position = position
        }
    }

    struct StringSet: Sendable, Equatable {
        public let state: String?
        public let values: [String]
        public let position: AbsolutePosition

        init(_ member: JSONMember) {
            state = member.value["state"]?.string
            values = member.value["values"]?.elements.compactMap(\.string) ?? []
            position = member.position
        }

        public var unit: StringUnit {
            StringUnit(state: state, value: values.joined(separator: "\n"), position: position)
        }
    }

    struct Variation: Sendable {
        public let kind: String
        public let position: AbsolutePosition
        public let cases: [VariationCase]

        init(_ member: JSONMember) {
            kind = member.key
            position = member.position
            cases = member.value.members.map(VariationCase.init)
        }
    }

    struct VariationCase: Sendable {
        public let name: String
        public let position: AbsolutePosition
        public let content: Content

        init(_ member: JSONMember) {
            name = member.key
            position = member.position
            content = Content(member.value, position: member.position)
        }
    }

    struct Substitution: Sendable {
        public let name: String
        public let position: AbsolutePosition
        public let argumentNumber: Int?
        public let formatSpecifier: String?
        public let variations: [Variation]

        init(_ member: JSONMember) {
            name = member.key
            position = member.position
            argumentNumber = member.value["argNum"]?.integer
            formatSpecifier = member.value["formatSpecifier"]?.string
            variations = (member.value["variations"]?.members ?? []).map(Variation.init)
        }
    }

    struct PluralGroup: Sendable {
        public let position: AbsolutePosition
        public let cases: [VariationCase]
        public let substitution: Substitution?

        public var categories: Set<PluralCategory> {
            Set(cases.compactMap { PluralCategory(rawValue: $0.name) })
        }

        public var hasExplicitZero: Bool {
            categories.contains(.zero)
        }
    }
}
