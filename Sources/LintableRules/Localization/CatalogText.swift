import LintableKit

enum CatalogText {
    static func quoted(_ text: String) -> String {
        let flattened = text.replacingOccurrences(of: "\n", with: " ")
        guard flattened.count > 60 else { return "“\(flattened)”" }
        return "“\(flattened.prefix(57))…”"
    }

    static func list(_ items: [String], conjunction: String = "and", limit: Int = 8) -> String {
        guard let last = items.last else { return "" }
        if items.count == 1 {
            return last
        }
        if items.count > limit {
            return items.prefix(limit).joined(separator: ", ") + " \(conjunction) \(items.count - limit) more"
        }
        return items.dropLast().joined(separator: ", ") + " \(conjunction) " + last
    }

    static func numbers(_ numbers: [Int]) -> String {
        let shown = numbers.prefix(3).map(String.init)
        return list(numbers.count > 3 ? shown + ["more"] : shown)
    }
}

struct ArgumentSignature: Equatable {
    private(set) var families: [Int: FormatSpecifier.Family] = [:]
    private(set) var placeholders: [String] = []

    init(_ content: StringCatalog.Content) {
        let reference = content.referenceContent
        let substitutions = reference.substitutions + content.substitutions
        var nextIndex = 1
        for specifier in FormatSpecifier.parse(reference.text) {
            switch specifier.kind {
            case .value:
                let index = specifier.argumentIndex ?? nextIndex
                if specifier.argumentIndex == nil {
                    nextIndex += 1
                }
                if let family = specifier.family {
                    families[index] = family
                }
                placeholders.append(specifier.text)
            case let .substitution(name):
                let substitution = substitutions.first { $0.name == name }
                let index = substitution?.argumentNumber ?? specifier.argumentIndex ?? nextIndex
                if substitution?.argumentNumber == nil, specifier.argumentIndex == nil {
                    nextIndex += 1
                }
                families[index] = FormatSpecifier.family(ofConversion: substitution?.formatSpecifier ?? "lld") ?? .integer
                placeholders.append(specifier.text)
            case .substitutionArgument:
                continue
            }
        }
    }

    static func == (lhs: ArgumentSignature, rhs: ArgumentSignature) -> Bool {
        lhs.families == rhs.families
    }

    var summary: String {
        placeholders.isEmpty ? "no placeholders" : placeholders.joined(separator: " ")
    }
}

enum EnglishCount {
    static let notPluralWords: Set<String> = [
        "afterwards", "always", "besides", "does", "ends", "equals", "gives", "goes", "happens", "has", "hers", "its",
        "keeps", "makes", "means", "needs", "news", "ours", "perhaps", "remains", "series", "shows", "species", "starts",
        "takes", "theirs", "towards", "uses", "was", "whereas", "yes", "yours",
    ]

    static func phraseForOne(in text: String, ignoring ignoredWords: Set<String>) -> String? {
        let bytes = Array(text.utf8)
        let inflected = inflectedSpans(in: bytes)
        for specifier in FormatSpecifier.parse(text) where specifier.isInteger {
            guard !inflected.contains(where: { $0.contains(specifier.utf8Range.lowerBound) }) else { continue }
            let words = followingWords(in: bytes, from: specifier.utf8Range.upperBound)
            if let phrase = pluralPhrase(words, ignoring: ignoredWords) {
                return "1 " + phrase
            }
        }
        return nil
    }

    private static func pluralPhrase(_ words: [String], ignoring ignoredWords: Set<String>) -> String? {
        guard let first = words.first else { return nil }
        if looksPlural(first, ignoring: ignoredWords) {
            return first
        }
        guard !first.lowercased().hasSuffix("s"), words.count > 1, looksPlural(words[1], ignoring: ignoredWords) else {
            return nil
        }
        return "\(first) \(words[1])"
    }

    private static func looksPlural(_ word: String, ignoring ignoredWords: Set<String>) -> Bool {
        let lowercased = word.lowercased()
        let singularEndings = ["ss", "us", "is"]
        return lowercased.count >= 3
            && lowercased.hasSuffix("s")
            && !singularEndings.contains { lowercased.hasSuffix($0) }
            && !notPluralWords.contains(lowercased)
            && !ignoredWords.contains(lowercased)
    }

    private static func followingWords(in bytes: [UInt8], from start: Int) -> [String] {
        var words: [String] = []
        var index = start
        while words.count < 2 {
            let spaceStart = index
            index = afterSpaces(in: bytes, from: index)
            guard index > spaceStart else { break }
            let wordStart = index
            while index < bytes.count, isLetter(bytes[index]) {
                index += 1
            }
            guard index > wordStart else { break }
            words.append(String(decoding: bytes[wordStart ..< index], as: UTF8.self))
        }
        return words
    }

    private static func afterSpaces(in bytes: [UInt8], from start: Int) -> Int {
        let noBreakSpace: [UInt8] = [0xC2, 0xA0]
        var index = start
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: " ") {
                index += 1
            } else if index + 1 < bytes.count, Array(bytes[index ... index + 1]) == noBreakSpace {
                index += 2
            } else {
                break
            }
        }
        return index
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(byte)
    }

    private static func inflectedSpans(in bytes: [UInt8]) -> [Range<Int>] {
        let opening = Array("^[".utf8)
        let closing = Array("](inflect".utf8)
        var spans: [Range<Int>] = []
        var searchStart = 0
        while let open = firstIndex(of: opening, in: bytes, from: searchStart) {
            guard let close = firstIndex(of: closing, in: bytes, from: open + opening.count) else { break }
            spans.append(open ..< close)
            searchStart = close + closing.count
        }
        return spans
    }

    private static func firstIndex(of pattern: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard pattern.count <= bytes.count, start <= bytes.count - pattern.count else { return nil }
        return (start ... bytes.count - pattern.count).first { Array(bytes[$0 ..< $0 + pattern.count]) == pattern }
    }
}
