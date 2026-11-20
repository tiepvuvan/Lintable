import Foundation

public enum PluralCategory: String, Sendable, CaseIterable, Comparable {
    case zero
    case one
    case two
    case few
    case many
    case other

    public static func < (lhs: PluralCategory, rhs: PluralCategory) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

public struct PluralRules: Sendable {
    public let language: String
    private let formula: Formula

    public init?(language identifier: String) {
        let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
        guard let formula = Self.formulas[normalized] ?? Self.formulas[base] else { return nil }
        language = identifier
        self.formula = formula
    }

    public func category(of number: Int, explicitZero: Bool = false) -> PluralCategory {
        if explicitZero, number == 0 {
            return .zero
        }
        return formula.category(abs(number))
    }

    public var requiredCategories: Set<PluralCategory> {
        Set((0 ... 1000).map { formula.category($0) }).union([.other])
    }

    public func numbers(in category: PluralCategory, explicitZero: Bool = false, through limit: Int = 200) -> [Int] {
        (0 ... limit).filter { self.category(of: $0, explicitZero: explicitZero) == category }
    }
}

private struct Formula: Sendable {
    let category: @Sendable (Int) -> PluralCategory
}

private extension Formula {
    static let otherOnly = Formula { _ in .other }

    static let oneForOne = Formula { $0 == 1 ? .one : .other }

    static let oneForZeroAndOne = Formula { $0 <= 1 ? .one : .other }

    static func romance(one: Set<Int>) -> Formula {
        Formula { number in
            if one.contains(number) {
                return .one
            }
            return number != 0 && number % 1_000_000 == 0 ? .many : .other
        }
    }

    static let eastSlavic = Formula { number in
        if number % 10 == 1, number % 100 != 11 {
            return .one
        }
        return (2 ... 4).contains(number % 10) && !(12 ... 14).contains(number % 100) ? .few : .many
    }

    static let polish = Formula { number in
        if number == 1 {
            return .one
        }
        return (2 ... 4).contains(number % 10) && !(12 ... 14).contains(number % 100) ? .few : .many
    }

    static let czech = Formula { number in
        if number == 1 {
            return .one
        }
        return (2 ... 4).contains(number) ? .few : .other
    }

    static let southSlavic = Formula { number in
        if number % 10 == 1, number % 100 != 11 {
            return .one
        }
        return (2 ... 4).contains(number % 10) && !(12 ... 14).contains(number % 100) ? .few : .other
    }

    static let slovenian = Formula { number in
        switch number % 100 {
        case 1:
            .one
        case 2:
            .two
        case 3, 4:
            .few
        default:
            .other
        }
    }

    static let lithuanian = Formula { number in
        if (11 ... 19).contains(number % 100) || number % 10 == 0 {
            return .other
        }
        return number % 10 == 1 ? .one : .few
    }

    static let latvian = Formula { number in
        if number % 10 == 0 || (11 ... 19).contains(number % 100) {
            return .zero
        }
        return number % 10 == 1 ? .one : .other
    }

    static let romanian = Formula { number in
        if number == 1 {
            return .one
        }
        return number == 0 || (1 ... 19).contains(number % 100) ? .few : .other
    }

    static let arabic = Formula { number in
        switch number {
        case 0:
            return .zero
        case 1:
            return .one
        case 2:
            return .two
        default:
            if (3 ... 10).contains(number % 100) {
                return .few
            }
            return (11 ... 99).contains(number % 100) ? .many : .other
        }
    }

    static let hebrew = Formula { number in
        switch number {
        case 1:
            .one
        case 2:
            .two
        default:
            .other
        }
    }

    static let icelandic = Formula { $0 % 10 == 1 && $0 % 100 != 11 ? .one : .other }

    static let filipino = Formula { number in
        [1, 2, 3].contains(number) || ![4, 6, 9].contains(number % 10) ? .one : .other
    }

    static let irish = Formula { number in
        switch number {
        case 1:
            .one
        case 2:
            .two
        case 3 ... 6:
            .few
        case 7 ... 10:
            .many
        default:
            .other
        }
    }

    static let welsh = Formula { number in
        switch number {
        case 0:
            .zero
        case 1:
            .one
        case 2:
            .two
        case 3:
            .few
        case 6:
            .many
        default:
            .other
        }
    }

    static let scottishGaelic = Formula { number in
        switch number {
        case 1, 11:
            .one
        case 2, 12:
            .two
        case 3 ... 10, 13 ... 19:
            .few
        default:
            .other
        }
    }

    static let maltese = Formula { number in
        switch number {
        case 1:
            return .one
        case 2:
            return .two
        default:
            if number == 0 || (3 ... 10).contains(number % 100) {
                return .few
            }
            return (11 ... 19).contains(number % 100) ? .many : .other
        }
    }
}

private extension PluralRules {
    static let formulaGroups: [(languages: [String], formula: Formula)] = [
        (
            [
                "bm", "bo", "dz", "id", "ig", "ii", "in", "ja", "jbo", "jv", "jw", "kde", "kea", "km", "ko", "lkt", "lo",
                "ms", "my", "nqo", "sah", "ses", "sg", "su", "th", "to", "vi", "wo", "yo", "yue", "zh",
            ],
            .otherOnly
        ),
        (
            [
                "af", "an", "asa", "ast", "az", "bem", "bez", "bg", "brx", "ce", "cgg", "chr", "ckb", "da", "de", "dv", "ee",
                "el", "en", "eo", "et", "eu", "fi", "fo", "fur", "fy", "gl", "gsw", "ha", "haw", "hu", "ia", "io", "jgo",
                "jmc", "ka", "kaj", "kcg", "kk", "kkj", "kl", "ks", "ksb", "ku", "ky", "lb", "lg", "lij", "mas", "mgo", "ml",
                "mn", "mr", "nah", "nb", "nd", "ne", "nl", "nn", "nnh", "no", "nr", "ny", "nyn", "om", "or", "os", "pap",
                "ps", "rm", "rof", "rwk", "saq", "sc", "scn", "sd", "sdh", "seh", "sn", "so", "sq", "ss", "ssy", "st", "sv",
                "sw", "syr", "ta", "te", "teo", "tig", "tk", "tn", "tr", "ts", "ug", "ur", "uz", "ve", "vo", "vun", "wae",
                "xh", "xog", "yi",
            ],
            .oneForOne
        ),
        (
            [
                "ak", "am", "as", "bho", "bn", "doi", "fa", "ff", "gu", "guw", "hi", "hy", "kab", "kn", "ln", "mg", "nso",
                "pa", "pcm", "ti", "wa", "zu",
            ],
            .oneForZeroAndOne
        ),
        (["ca", "es", "it", "pt-pt", "vec"], .romance(one: [1])),
        (["fr", "pt"], .romance(one: [0, 1])),
        (["be", "ru", "uk"], .eastSlavic),
        (["pl"], .polish),
        (["cs", "sk"], .czech),
        (["bs", "hr", "sh", "sr"], .southSlavic),
        (["sl"], .slovenian),
        (["lt"], .lithuanian),
        (["lv", "prg"], .latvian),
        (["mo", "ro"], .romanian),
        (["ar", "ars"], .arabic),
        (["he", "iw"], .hebrew),
        (["is", "mk"], .icelandic),
        (["fil", "tl"], .filipino),
        (["ga"], .irish),
        (["cy"], .welsh),
        (["gd"], .scottishGaelic),
        (["mt"], .maltese),
    ]

    static let formulas: [String: Formula] = Dictionary(
        formulaGroups.flatMap { group in group.languages.map { ($0, group.formula) } },
        uniquingKeysWith: { first, _ in first }
    )
}
