import LintableKit
import SwiftSyntax
import Testing

@Suite struct JSONDocumentTests {
    @Test func parsesValuesAndRemembersWhereEachKeyStarts() throws {
        let source = """
        {
          "name" : "Habit",
          "count" : -12.5e3,
          "flags" : [true, false, null],
          "nested" : { "inner" : "x" }
        }
        """
        let value = try JSONDocument.parse(source)
        #expect(value["name"]?.string == "Habit")
        #expect(value["count"] == .number("-12.5e3"))
        #expect(value["flags"]?.elements == [.bool(true), .bool(false), .null])
        #expect(value["nested"]?["inner"]?.string == "x")
        let offset = try #require(value.member("nested")?.position.utf8Offset)
        let bytes = Array(source.utf8)
        #expect(String(decoding: bytes[offset ..< offset + 8], as: UTF8.self) == "\"nested\"")
    }

    @Test func decodesEscapes() throws {
        let value = try JSONDocument.parse(#"{ "text" : "a\"b\\c\/d\né😀" }"#)
        #expect(value["text"]?.string == "a\"b\\c/d\né😀")
    }

    @Test(arguments: [
        ("{ \"a\" : 1, }", "Expected a key in double quotes."),
        ("{ \"a\" : \"open }", "The string isn't closed."),
        ("{ \"a\" 1 }", "Expected `:` after the key."),
        ("[1 2]", "Expected `,` or `]` in the array."),
        ("{} {}", "Expected the end of the file after the JSON value."),
        ("{ \"a\" : tru }", "Expected a value."),
        (#"{ "a" : "\q" }"#, "Unknown escape `\\q` in the string."),
    ])
    func reportsWhatIsWrong(source: String, reason: String) {
        #expect(throws: JSONParseError.self) {
            try JSONDocument.parse(source)
        }
        do {
            _ = try JSONDocument.parse(source)
        } catch let error as JSONParseError {
            #expect(error.reason == reason)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}

@Suite struct StringCatalogTests {
    private let source = """
    {
      "sourceLanguage" : "en",
      "strings" : {
        "%lld of %lld items" : {
          "comment" : "Progress.",
          "localizations" : {
            "en" : {
              "stringUnit" : { "state" : "translated", "value" : "%1$lld of %#@items@" },
              "substitutions" : {
                "items" : {
                  "argNum" : 2,
                  "formatSpecifier" : "lld",
                  "variations" : {
                    "plural" : {
                      "one" : { "stringUnit" : { "state" : "translated", "value" : "%arg item" } },
                      "other" : { "stringUnit" : { "state" : "translated", "value" : "%arg items" } }
                    }
                  }
                }
              }
            },
            "ru" : {
              "variations" : {
                "plural" : {
                  "few" : { "stringUnit" : { "state" : "translated", "value" : "%1$lld из %2$lld пунктов" } },
                  "other" : { "stringUnit" : { "state" : "translated", "value" : "%1$lld из %2$lld" } }
                }
              }
            }
          }
        },
        "Done" : {
        },
        "Old" : {
          "extractionState" : "stale"
        },
        "Habitify" : {
          "shouldTranslate" : false
        }
      },
      "version" : "1.0"
    }
    """

    @Test func readsEntriesInFileOrder() throws {
        let catalog = try StringCatalog(path: "Localizable.xcstrings", source: source)
        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.targetLanguages == ["ru"])
        #expect(catalog.entries.map(\.key) == ["%lld of %lld items", "Done", "Old", "Habitify"])
        #expect(catalog.entries.map(\.needsTranslation) == [true, true, false, false])
        #expect(catalog.entries[0].comment == "Progress.")
        let location = catalog.location(of: catalog.entries[1].position)
        #expect(location == LineColumn(line: 32, column: 5))
        #expect(catalog.lineText(location.line) == "\"Done\" : {")
    }

    @Test func fallsBackToTheKeyForTheSourceText() throws {
        let catalog = try StringCatalog(path: "Localizable.xcstrings", source: source)
        #expect(catalog.sourceContent(of: catalog.entries[1]).text == "Done")
        #expect(catalog.translations(of: catalog.entries[0]).map(\.language) == ["ru"])
    }

    @Test func findsPluralGroupsInVariationsAndSubstitutions() throws {
        let catalog = try StringCatalog(path: "Localizable.xcstrings", source: source)
        let entry = catalog.entries[0]
        let english = try #require(entry.localization(for: "en")).content
        #expect(english.text == "%1$lld of %#@items@")
        #expect(english.pluralGroups.map(\.categories) == [[.one, .other]])
        #expect(english.pluralGroups.first?.substitution?.argumentNumber == 2)
        let russian = try #require(entry.localization(for: "ru")).content
        #expect(russian.text == "%1$lld из %2$lld")
        #expect(russian.pluralGroups.map(\.categories) == [[.few, .other]])
        #expect(russian.units.count == 2)
    }

    @Test func readsAppShortcutPhraseSets() throws {
        let catalog = try StringCatalog(path: "AppShortcuts.xcstrings", source: """
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Log ${habit} in ${applicationName}" : {
              "localizations" : {
                "de" : { "stringSet" : { "state" : "translated", "values" : ["${habit} in ${applicationName} abhaken", "${habit} erledigt"] } }
              }
            }
          },
          "version" : "1.0"
        }
        """)
        let german = try #require(catalog.entries.first?.localization(for: "de")).content
        #expect(german.stringSet?.values.count == 2)
        #expect(german.units.map(\.state) == ["translated"])
        #expect(german.text == "${habit} in ${applicationName} abhaken\n${habit} erledigt")
    }

    @Test func reportsWhereTheCatalogIsBroken() {
        #expect(throws: StringCatalogError(line: 3, column: 1, reason: "Expected `,` or `}` in the object.")) {
            try StringCatalog(path: "Broken.xcstrings", source: "{\n  \"sourceLanguage\" : \"en\"\n\"strings\" : {}\n}")
        }
        #expect(throws: StringCatalogError(line: 1, column: 1, reason: "A String Catalog is a JSON object.")) {
            try StringCatalog(path: "Broken.xcstrings", source: "[]")
        }
    }
}

@Suite struct FormatSpecifierTests {
    @Test func findsSpecifiersAndWhatTheyRead() {
        let specifiers = FormatSpecifier.parse("%1$@ has %2$lld habits, 100%% done, %.1f%%, %02lld:%02lld, %#@days@ %arg")
        #expect(specifiers.map(\.text) == ["%1$@", "%2$lld", "%.1f", "%02lld", "%02lld", "%#@days@", "%arg"])
        #expect(specifiers.map(\.argumentIndex) == [1, 2, nil, nil, nil, nil, nil])
        #expect(specifiers.map(\.family) == [.object, .integer, .float, .integer, .integer, nil, nil])
        #expect(specifiers[5].kind == .substitution(name: "days"))
        #expect(specifiers[6].kind == .substitutionArgument)
        #expect(specifiers.allSatisfy { $0.showsNumber || $0.family == .object })
    }

    @Test(arguments: ["Save 50% on Pro", "100%", "% d", "Just text"])
    func ignoresTextThatIsNotASpecifier(text: String) {
        #expect(FormatSpecifier.parse(text).isEmpty)
    }

    @Test func knowsWhereEachSpecifierIs() {
        let specifiers = FormatSpecifier.parse("%lldd and %@")
        #expect(specifiers.map(\.utf8Range) == [0 ..< 4, 10 ..< 12])
    }
}

@Suite struct PluralRulesTests {
    @Test func russianUsesOneForEveryNumberEndingInOneExceptEleven() throws {
        let rules = try #require(PluralRules(language: "ru"))
        let categories = [0, 1, 2, 4, 5, 11, 12, 21, 22, 25, 101, 111].map { rules.category(of: $0) }
        #expect(categories == [.many, .one, .few, .few, .many, .many, .many, .one, .few, .many, .one, .many])
        #expect(rules.requiredCategories == [.one, .few, .many, .other])
        #expect(rules.numbers(in: .one, through: 50) == [1, 21, 31, 41])
    }

    @Test func frenchUsesOneForZeroAndOneUnlessThereIsAZeroForm() throws {
        let rules = try #require(PluralRules(language: "fr"))
        #expect(rules.category(of: 0) == .one)
        #expect(rules.category(of: 1_000_000) == .many)
        #expect(rules.requiredCategories == [.one, .other])
        #expect(rules.numbers(in: .one) == [0, 1])
        #expect(rules.numbers(in: .one, explicitZero: true) == [1])
        #expect(rules.category(of: 0, explicitZero: true) == .zero)
    }

    @Test func arabicNeedsAllSixForms() throws {
        let rules = try #require(PluralRules(language: "ar-SA"))
        #expect([0, 1, 2, 3, 11, 100].map { rules.category(of: $0) } == [.zero, .one, .two, .few, .many, .other])
        #expect(rules.requiredCategories == Set(PluralCategory.allCases))
    }

    static let requiredCategoryCases: [(language: String, categories: Set<PluralCategory>)] = [
        ("ja", [.other]),
        ("zh-Hans", [.other]),
        ("en_GB", [.one, .other]),
        ("pl", [.one, .few, .many, .other]),
        ("cs", [.one, .few, .other]),
        ("sr-Latn", [.one, .few, .other]),
        ("sl", [.one, .two, .few, .other]),
        ("he", [.one, .two, .other]),
        ("lv", [.zero, .one, .other]),
        ("pt-PT", [.one, .other]),
    ]

    @Test(arguments: requiredCategoryCases)
    func requiredCategories(language: String, categories: Set<PluralCategory>) throws {
        #expect(try #require(PluralRules(language: language)).requiredCategories == categories)
    }

    @Test func portugalAndBrazilDifferForZero() throws {
        #expect(try #require(PluralRules(language: "pt-PT")).category(of: 0) == .other)
        #expect(try #require(PluralRules(language: "pt-BR")).category(of: 0) == .one)
    }

    @Test func unknownLanguagesHaveNoRules() {
        #expect(PluralRules(language: "tlh") == nil)
    }
}
