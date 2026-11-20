import LintableRules
import LintableTesting
import Testing

@Suite struct LocalizationCodeExampleTests {
    @Test func examplesAreCorrect() {
        verifyExamples(of: HardcodedUITextRule.self)
        verifyExamples(of: EnglishPluralLogicRule.self)
        verifyExamples(of: NumberAsTextInLocalizedStringRule.self)
        verifyExamples(of: LocalizedConcatenationRule.self)
        verifyExamples(of: MissingTranslatorCommentRule.self)
    }
}

@Suite struct HardcodedUITextRuleTests {
    @Test func reportsInterpolatedTextAndNotificationText() {
        assertLint(HardcodedUITextRule.self, """
        func notify(name: String) {
            label.text = 1️⃣"Hello \\(name)"
            content.body = 2️⃣"Received a new reminder"
            cell.reuseIdentifier = "HabitCell"
            imageName.text = "chevron.right"
        }
        """, messages: [
            "1️⃣": "“Hello ” reaches `text` without being localized. Use `String(localized:comment:)` so translators see it.",
        ])
    }

    @Test func skipsPreviews() {
        assertLint(HardcodedUITextRule.self, """
        #Preview {
            let label = UILabel()
            label.text = "Preview text"
            return label
        }

        struct Row_Previews: PreviewProvider {
            static var previews: some View {
                Text(verbatim: "Sample habit name")
            }
        }
        """)
    }

    @Test func usesTheConfiguredSinks() {
        assertLint(HardcodedUITextRule.self, options: "properties: [caption]\ncalls: [\"Toast(message:)\"]", """
        func show() {
            badge.caption = 1️⃣"New"
            Toast(message: 2️⃣"Saved")
            label.text = "Not checked"
        }
        """)
    }
}

@Suite struct EnglishPluralLogicRuleTests {
    @Test func reportsComparisonsWithOneOrTwo() {
        assertLint(EnglishPluralLogicRule.self, """
        let first = 1️⃣count != 1 ? "s" : ""
        let second = 2️⃣count < 2 ? "item" : "items"
        let third = count > 3 ? "many" : "few"
        let fourth = isPlural ? "items" : "item"
        """, messages: [
            "1️⃣": "Choosing “s” or “” by comparing a count with 1 only works in English. Vary a localized string by plural instead.",
        ])
    }
}

@Suite struct NumberAsTextInLocalizedStringRuleTests {
    @Test func reportsConversionsInEveryLocalizedInitializer() {
        assertLint(NumberAsTextInLocalizedStringRule.self, """
        let first = LocalizedStringResource("\\(1️⃣String(describing: remainingCount)) left")
        let skipped = String(localized: "\\(String(name.characters)) note", comment: "Title.")
        let second = AttributedString(localized: "\\(2️⃣count.description) habits")
        let third = Text("\\(date.formatted()) at \\(time)")
        let fourth = String(localized: "\\(count) habits", comment: "Count.")
        """)
    }
}

@Suite struct LocalizedConcatenationRuleTests {
    @Test func reportsPiecesJoinedByPlusOrInterpolation() {
        assertLint(LocalizedConcatenationRule.self, """
        let first = 1️⃣NSLocalizedString("Completed", comment: "") + "!"
        let second = 2️⃣"\\(String(localized: "Day", comment: "")) \\(number)"
        let third = "\\(String(localized: "Day", comment: ""))"
        let fourth = title + subtitle
        """)
    }
}
