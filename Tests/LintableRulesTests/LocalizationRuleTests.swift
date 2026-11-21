import LintableRules
import LintableTesting
import Testing

private func catalog(_ strings: String, source: String = "en") -> String {
    """
    {
      "sourceLanguage" : "\(source)",
      "strings" : {
    \(strings)
      },
      "version" : "1.0"
    }
    """
}

private func unit(_ value: String, state: String = "translated") -> String {
    #"{ "stringUnit" : { "state" : "\#(state)", "value" : "\#(value)" } }"#
}

private func plural(_ forms: [(String, String)]) -> String {
    let cases = forms.map { "\"\($0.0)\" : \(unit($0.1))" }.joined(separator: ", ")
    return #"{ "variations" : { "plural" : { \#(cases) } } }"#
}

@Suite struct LocalizationExampleTests {
    @Test func examplesAreCorrect() {
        verifyExamples(of: MissingTranslationRule.self)
        verifyExamples(of: PlaceholderMismatchRule.self)
        verifyExamples(of: MissingPluralFormRule.self)
        verifyExamples(of: PluralFormWithoutNumberRule.self)
        verifyExamples(of: NumberWithoutPluralRule.self)
        verifyExamples(of: StaleStringRule.self)
        verifyExamples(of: MissingPackageStringRule.self)
    }
}

@Suite struct MissingTranslationRuleTests {
    @Test func listsTheMissingAndUnfinishedLanguages() {
        assertCatalogLint(MissingTranslationRule.self, catalog("""
            1️⃣"Done" : { "localizations" : { "de" : \(unit("Fertig")), "en-GB" : \(unit("Done", state: "new")) } },
            "Save" : { "localizations" : { "de" : \(unit("Sichern")), "en-GB" : \(unit("Save")), "fr" : \(unit("Enregistrer")) } }
        """), messages: ["1️⃣": "“Done” isn't translated into fr; it is still `new` in en-GB."])
    }

    @Test func checksOnlyTheConfiguredLanguages() {
        assertCatalogLint(MissingTranslationRule.self, options: "languages: [de]", catalog("""
            "Done" : { "localizations" : { "de" : \(unit("Fertig")) } },
            "Save" : { "localizations" : { "de" : \(unit("Sichern")), "fr" : \(unit("Enregistrer")) } }
        """))
    }

    @Test func acceptsTheConfiguredStates() {
        assertCatalogLint(MissingTranslationRule.self, options: "accepted_states: [translated, needs_review]", catalog("""
            "Done" : { "localizations" : { "de" : \(unit("Fertig", state: "needs_review")) } }
        """))
    }

    @Test func readsPhraseSetsLikeOtherTranslations() {
        assertCatalogLint(MissingTranslationRule.self, catalog("""
            "Log ${habit} in ${applicationName}" : { "localizations" : {
              "de" : { "stringSet" : { "state" : "translated", "values" : ["${habit} in ${applicationName} abhaken"] } },
              "en" : { "stringSet" : { "state" : "new", "values" : ["Log ${habit} in ${applicationName}"] } }
            } }
        """))
    }

    @Test func shortensLongKeysAndLanguageLists() {
        let languages = ["af", "ar", "cs", "da", "de", "el", "es", "fi", "fr", "he"]
        let translated = languages.map { "\"\($0)\" : \(unit("x"))" }.joined(separator: ", ")
        let key = String(repeating: "long ", count: 20)
        assertCatalogLint(MissingTranslationRule.self, catalog("""
            1️⃣"\(key)" : { "localizations" : { "ja" : \(unit("x")) } },
            "Other" : { "localizations" : { \(translated), "ja" : \(unit("x")) } }
        """), messages: [
            "1️⃣": "“long long long long long long long long long long long lo…” isn't translated into "
                + "af, ar, cs, da, de, el, es, fi and 2 more.",
        ])
    }
}

@Suite struct PlaceholderMismatchRuleTests {
    @Test func reportsAMissingOrDifferentArgument() {
        assertCatalogLint(PlaceholderMismatchRule.self, catalog("""
            "%1$@ has %2$lld habits" : { "localizations" : {
              1️⃣"de" : \(unit("%1$@ hat Gewohnheiten")),
              2️⃣"fr" : \(unit("%1$@ a %2$@ habitudes")),
              "it" : \(unit("%1$@ ha %2$d abitudini")),
              "ja" : \(plural([("other", "%2$lld 個 %1$@")]))
            } }
        """), messages: [
            "1️⃣": "The de translation of “%1$@ has %2$lld habits” has %1$@ where the source has %1$@ %2$lld.",
            "2️⃣": "The fr translation of “%1$@ has %2$lld habits” has %1$@ %2$@ where the source has %1$@ %2$lld.",
        ])
    }

    @Test func comparesSubstitutionsByArgumentNumber() {
        assertCatalogLint(PlaceholderMismatchRule.self, catalog("""
            "%lld of %lld items" : { "localizations" : {
              "en" : {
                "stringUnit" : { "state" : "translated", "value" : "%1$lld of %#@items@" },
                "substitutions" : { "items" : { "argNum" : 2, "formatSpecifier" : "lld", "variations" : { "plural" : {
                  "one" : \(unit("%arg item")), "other" : \(unit("%arg items"))
                } } } }
              },
              "ja" : \(unit("%1$lld/%2$lld 件"))
            } }
        """))
    }
}

@Suite struct MissingPluralFormRuleTests {
    @Test func checksTheSourceLanguageAndSubstitutionsToo() {
        assertCatalogLint(MissingPluralFormRule.self, catalog("""
            "%lld habits" : { "localizations" : {
              "en" : { "variations" : { 1️⃣"plural" : { "other" : \(unit("%lld habits")) } } },
              "pl" : {
                "stringUnit" : { "state" : "translated", "value" : "%#@habits@" },
                "substitutions" : { "habits" : { "argNum" : 1, "formatSpecifier" : "lld", "variations" : { 2️⃣"plural" : {
                  "one" : \(unit("%arg nawyk")), "other" : \(unit("%arg nawyku"))
                } } } }
              },
              "tlh" : \(plural([("other", "%lld")]))
            } }
        """), messages: [
            "1️⃣": "The en plural of “%lld habits” has no one form.",
            "2️⃣": "The pl plural of “%lld habits” has no few or many form.",
        ])
    }
}

@Suite struct PluralFormWithoutNumberRuleTests {
    @Test func reportsFormsThatHideWhichNumberTheyShow() {
        assertCatalogLint(PluralFormWithoutNumberRule.self, catalog("""
            "Last %lld days" : { "localizations" : {
              "ar" : \(plural([("few", "%lld أيام"), ("many", "%lld يومًا"), ("one", "يوم"), ("other", "%lld يوم"), ("two", "يومان"), ("zero", "لا أيام")])),
              "fr" : { "variations" : { "plural" : { 1️⃣"one" : \(unit("Dernier jour")), "other" : \(unit("%lld derniers jours")) } } },
              "lv" : { "variations" : { "plural" : { "one" : \(unit("%lld diena")), "other" : \(unit("%lld dienas")), 2️⃣"zero" : \(unit("Nav dienu")) } } },
              "ru" : { "variations" : { "plural" : { "few" : \(unit("%lld дня")), "many" : \(unit("%lld дней")), 3️⃣"one" : \(unit("Последний день")), "other" : \(unit("%lld дня")) } } }
            } }
        """), messages: [
            "1️⃣": "The fr “one” form of “Last %lld days” is used for 0 and 1, but “Dernier jour” doesn't show the number.",
            "2️⃣": "The lv “zero” form of “Last %lld days” is used for 0, 10, 11 and more, but “Nav dienu” doesn't show the number.",
            "3️⃣": "The ru “one” form of “Last %lld days” is used for 1, 21, 31 and more, but “Последний день” doesn't show the number.",
        ])
    }
}

@Suite struct NumberWithoutPluralRuleTests {
    @Test func reportsTheFirstCountedNoun() {
        assertCatalogLint(NumberWithoutPluralRule.self, catalog("""
            1️⃣"%lld completed habits" : { },
            2️⃣"%1$lld/%2$lld items" : { },
            "%lld is your best" : { },
            "Setting %lld means daily" : { },
            "%lldd" : { },
            "%lld this week" : { }
        """), messages: [
            "1️⃣": "“%lld completed habits” reads “1 completed habits” when the number is 1. Vary it by plural.",
            "2️⃣": "“%1$lld/%2$lld items” reads “1 items” when the number is 1. Vary it by plural.",
        ])
    }

    @Test func honorsTheOptions() {
        assertCatalogLint(NumberWithoutPluralRule.self, options: "ignored_keys: [\"%lld records\"]\nignored_words: [kcals]", catalog("""
            "%lld records" : { },
            "%lld kcals" : { }
        """))
    }

    @Test func skipsCatalogsWhoseSourceIsNotEnglish() {
        assertCatalogLint(NumberWithoutPluralRule.self, catalog("""
            "%lld Gewohnheiten" : { }
        """, source: "de"))
    }
}

@Suite struct StaleStringRuleTests {
    @Test func reportsStaleKeys() {
        assertCatalogLint(StaleStringRule.self, catalog("""
            1️⃣"Old" : { "extractionState" : "stale" },
            "New" : { "extractionState" : "extracted_with_value" }
        """), messages: ["1️⃣": "“Old” is stale: the code no longer uses it."])
    }

    @Test func skipsIgnoredKeys() {
        assertCatalogLint(StaleStringRule.self, options: "ignored_keys: [Dormant]", catalog("""
            1️⃣"Old" : { "extractionState" : "stale" },
            "Dormant" : { "extractionState" : "stale" }
        """))
    }
}

@Suite struct MissingPackageStringRuleTests {
    private static let package = catalog("""
        "Log Habit" : { },
        "Which habit?" : { },
        "Arrive" : { },
        "Removed" : { "extractionState" : "stale" }
    """)

    private static let options = """
    hosts:
      - catalog: App/Localizable.xcstrings
        packages: [Kit/Localizable.xcstrings]
    """

    @Test func listsTheMissingStringsOnce() {
        assertCatalogLint(
            MissingPackageStringRule.self,
            options: "hosts: [{ catalog: Example.xcstrings, packages: [Kit/Localizable.xcstrings] }]",
            "1️⃣" + catalog("""
                "Log Habit" : { "extractionState" : "manual" }
            """),
            files: ["Kit/Localizable.xcstrings": Self.package],
            messages: ["1️⃣": "2 strings of Kit/Localizable.xcstrings are missing here: “Which habit?”, “Arrive”. Copy the entries with their comments and translations, and set their extraction state to manual."]
        )
    }

    @Test func reportsStaleCopiesAndUnusedManualCopies() {
        assertCatalogLint(
            MissingPackageStringRule.self,
            options: "hosts: [{ catalog: ./Example.xcstrings, packages: [Kit/Localizable.xcstrings] }]",
            catalog("""
                1️⃣"Log Habit" : { "extractionState" : "stale" },
                "Which habit?" : { },
                "Arrive" : { "extractionState" : "manual" },
                2️⃣"Removed" : { "extractionState" : "manual" }
            """),
            files: ["Kit/Localizable.xcstrings": Self.package],
            messages: [
                "1️⃣": "“Log Habit” is stale here, but Kit/Localizable.xcstrings still uses it, and this target reads it from this catalog. Set its extraction state to manual.",
                "2️⃣": "“Removed” is kept by hand for a package, but no package catalog listed for this catalog uses it anymore. Delete it.",
            ]
        )
    }

    @Test func keepsUnusedManualCopiesWhenAsked() {
        assertCatalogLint(
            MissingPackageStringRule.self,
            options: "hosts: [{ catalog: Example.xcstrings, packages: [Kit/Localizable.xcstrings] }]\nreport_unused_copies: false",
            catalog("""
                "Log Habit" : { }, "Which habit?" : { }, "Arrive" : { },
                "Dynamic key" : { "extractionState" : "manual" }
            """),
            files: ["Kit/Localizable.xcstrings": Self.package]
        )
    }

    @Test func ignoresCatalogsThatAreNotHosts() {
        assertCatalogLint(MissingPackageStringRule.self, options: Self.options, catalog("""
            "Other" : { }
        """), files: ["Kit/Localizable.xcstrings": Self.package])
    }

    @Test func reportsAPackageCatalogItCannotRead() {
        assertCatalogLint(
            MissingPackageStringRule.self,
            options: "hosts: [{ catalog: Example.xcstrings, packages: [Kit/Missing.xcstrings] }]",
            "1️⃣" + catalog("""
                "Other" : { }
            """),
            messages: ["1️⃣": "The config names Kit/Missing.xcstrings as a package catalog for this one, but it isn't a String Catalog Lintable can read."]
        )
    }
}
