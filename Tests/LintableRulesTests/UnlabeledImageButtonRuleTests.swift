import LintableRules
import LintableTesting
import Testing

@Suite struct UnlabeledImageButtonExampleTests {
    @Test func examplesAreCorrect() {
        verifyExamples(of: UnlabeledImageButtonRule.self)
    }
}

@Suite struct UnlabeledImageButtonSwiftUITests {
    @Test func reportsEveryWayToWriteAnImageOnlyLabel() {
        assertLint(UnlabeledImageButtonRule.self, """
        struct Toolbar: View {
            var body: some View {
                1️⃣Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                2️⃣Button(action: share, label: {
                    Image(decorative: "Share")
                })
                3️⃣SwiftUI.Button(action: close) {
                    ZStack {
                        Circle().fill(Color.gray)
                        Image(.close24).resizable()
                    }
                }
                4️⃣Menu {
                    Button("Edit", action: edit)
                } label: {
                    Image(systemName: "ellipsis")
                }
                5️⃣NavigationLink(destination: SettingsView()) {
                    Image("Gear")
                }
                6️⃣Link(destination: helpURL) {
                    AsyncImage(url: iconURL)
                }
                7️⃣Button(action: toggle) {
                    if isOn {
                        Image(systemName: "checkmark")
                    } else {
                        Color.clear
                    }
                }
                .accessibility(hint: Text("Toggles the reminder"))
            }
        }
        """, messages: [
            "1️⃣": "This `Button` shows only an image, so VoiceOver can only read the image's name. "
                + "Add `.accessibilityLabel(Text(…))` with a localized description of what it does.",
            "4️⃣": "This `Menu` shows only an image, so VoiceOver can only read the image's name. "
                + "Add `.accessibilityLabel(Text(…))` with a localized description of what it does.",
        ])
    }

    @Test func acceptsLabelsTextAndUnknownViews() {
        assertLint(UnlabeledImageButtonRule.self, """
        struct Toolbar: View {
            var body: some View {
                Button(action: dismiss) {
                    Image(.close24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close", comment: "Closes the offer."))
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .accessibilityLabel(Text("Share", comment: "Shares the habit."))
                }
                Button(action: remove) {
                    Image(systemName: "trash")
                }
                .accessibility(label: Text("Delete", comment: "Deletes the habit."))
                Button(action: add) {
                    HStack {
                        Image(.plus24)
                        Text("Add habit", comment: "Adds a habit.")
                    }
                }
                Button(action: open) {
                    Label("Open", systemImage: "arrow.up.right")
                }
                Button("Done", systemImage: "checkmark", action: save)
                Button(action: pick) {
                    ColorSwatchView(color: color)
                }
                Button(action: edit) {
                    Image("Pencil", label: Text("Edit", comment: "Edits the note."))
                }
                Menu("More") {
                    Button("Edit", action: edit)
                }
            }
        }
        """)
    }

    @Test func needsALabelOnEveryImageItCanShow() {
        assertLint(UnlabeledImageButtonRule.self, """
        struct MoodButton: View {
            var body: some View {
                1️⃣Button(action: toggle) {
                    if isFocused {
                        Image("Mood Filled")
                            .accessibilityLabel(Text("Mood", comment: "Opens the mood picker."))
                    } else {
                        Image("Mood Stroke")
                    }
                }
                Button(action: toggle) {
                    if isFocused {
                        Image("Mood Filled")
                    } else {
                        Image("Mood Stroke")
                    }
                }
                .accessibilityLabel(Text("Mood", comment: "Opens the mood picker."))
                Button(action: toggle) {
                    ZStack {
                        Image("Badge")
                        Image("Mood Stroke")
                    }
                    .accessibilityLabel(Text("Mood", comment: "Opens the mood picker."))
                }
            }
        }
        """)
    }

    @Test func acceptsALabelAddedWhereTheButtonIsUsed() {
        assertLint(UnlabeledImageButtonRule.self, """
        struct Header: View {
            var body: some View {
                HStack {
                    closeButton
                        .padding(8)
                        .accessibilityLabel(Text("Close", comment: "Closes the screen."))
                    iconButton("Filter", action: filter)
                        .accessibilityLabel(Text("Filter", comment: "Filters the list."))
                }
            }

            private var closeButton: some View {
                Button(action: dismiss) {
                    Image(.close24)
                }
                .buttonStyle(.plain)
            }

            private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
                Button(action: action) {
                    Image(name)
                }
            }

            private var shareButton: some View {
                1️⃣Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        """)
    }

    @Test func skipsPreviewsAndDebugCode() {
        assertLint(UnlabeledImageButtonRule.self, """
        #Preview {
            Button(action: {}) {
                Image(systemName: "xmark")
            }
        }

        struct DebugMenu: View {
            var body: some View {
                #if DEBUG
                    Button(action: reset) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                #endif
            }
        }
        """)
    }

    @Test func usesTheConfiguredControlsAndModifiers() {
        assertLint(UnlabeledImageButtonRule.self, options: "swiftui_controls: [Button]\nlabel_modifiers: [a11yLabel]", """
        struct Toolbar: View {
            var body: some View {
                Menu {
                    Button("Edit", action: edit)
                } label: {
                    Image(systemName: "ellipsis")
                }
                Button(action: close) {
                    Image(.close24)
                }
                .a11yLabel("Close")
                1️⃣Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Share", comment: "Shares the habit."))
            }
        }
        """)
    }
}

@Suite struct UnlabeledImageButtonUIKitTests {
    @Test func reportsImageOnlyButtons() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class SelectionBar: UIView {
            private let endButton = UIButton()
            private let sortButton = UIButton()
            private let doneButton = UIButton()

            func configure() {
                1️⃣endButton.setImage(.close24, for: .normal)
                endButton.setImage(.close24, for: .highlighted)
                2️⃣self.sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
                sortButton.setTitle(nil, for: .normal)
                3️⃣doneButton.setImage(.check20, for: .normal)
                doneButton.setTitle("", for: .normal)
                doneButton.accessibilityLabel = nil
            }
        }
        """, messages: [
            "1️⃣": "`endButton` shows only an image, so VoiceOver can only read the image's name. "
                + "Set its `accessibilityLabel` to a localized description of what it does.",
        ])
    }

    @Test func acceptsTitlesAndLabelsAnywhereInTheTypeAndItsExtensions() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class SelectionBar: UIView {
            private let endButton = UIButton()
            private let completeButton = UIButton()
            private let tagButton = UIButton()
            private let hiddenButton = UIButton()
            private let clearButton = UIButton()

            func configure() {
                endButton.setImage(.close24, for: .normal)
                completeButton.setImage(.check20, for: .normal)
                completeButton.setTitle(String(localized: "Complete", comment: "Completes the habits."), for: .normal)
                tagButton.setImage(.tag, for: .normal)
                tagButton.titleLabel?.text = tagName
                hiddenButton.setImage(.dot, for: .normal)
                hiddenButton.isAccessibilityElement = false
                clearButton.setImage(nil, for: .normal)
            }
        }

        extension SelectionBar {
            func localize() {
                endButton.accessibilityLabel = String(localized: "Cancel", comment: "Ends selecting habits.")
            }
        }
        """)
    }

    @Test func followsLocalsIntoTheirProperties() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class DateSelectorViewController: UIViewController {
            var addButton: UIButton = {
                let button = UIButton()
                1️⃣button.setImage(UIImage(named: "JournalAdd"), for: .normal)
                return button
            }()

            private lazy var jumpButton: UIButton = {
                let button = UIButton()
                button.setImage(.init(named: "quickJump"), for: .normal)
                return button
            }()

            private var closeButton: UIButton?

            override func viewDidLoad() {
                super.viewDidLoad()
                jumpButton.accessibilityLabel = String(localized: "Today", comment: "Jumps to today.")
                let button = UIButton(type: .system)
                button.setImage(.close24, for: .normal)
                closeButton = button
                closeButton?.accessibilityLabel = String(localized: "Close", comment: "Closes the date selector.")
                let shareButton = UIButton(type: .system)
                2️⃣shareButton.setImage(.share, for: .normal)
                view.addSubview(shareButton)
            }
        }
        """, messages: [
            "1️⃣": "`addButton` shows only an image, so VoiceOver can only read the image's name. "
                + "Set its `accessibilityLabel` to a localized description of what it does.",
            "2️⃣": "`shareButton` shows only an image, so VoiceOver can only read the image's name. "
                + "Set its `accessibilityLabel` to a localized description of what it does.",
        ])
    }

    @Test func leavesButtonsItCantFollowToTheirCallers() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class IconButton: UIButton {
            init(icon: UIImage) {
                super.init(frame: .zero)
                setImage(icon, for: .normal)
                self.setImage(icon, for: .highlighted)
            }
        }

        final class Toolbar: UIView {
            static func makeButton(image: UIImage?) -> UIButton {
                let button = UIButton()
                button.setImage(image, for: .normal)
                return button
            }

            func style(_ button: UIButton, with image: UIImage) {
                button.setImage(image, for: .normal)
            }

            func styleAll(_ buttons: [UIButton]) {
                for button in buttons {
                    button.setImage(.dot, for: .normal)
                }
                buttons.forEach { $0.setImage(.dot, for: .normal) }
            }
        }
        """)
    }

    @Test func followsButtonConfigurations() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class Header: UIView {
            private let searchButton = UIButton()
            private let habiButton = UIButton()
            private let filterButton = UIButton()
            private let menuButton = UIButton()

            func configure() {
                var searchConfiguration = UIButton.Configuration.plain()
                searchConfiguration.image = UIImage(systemName: "magnifyingglass")
                1️⃣searchButton.configuration = searchConfiguration

                var habiConfiguration = UIButton.Configuration.plain()
                habiConfiguration.image = .habi28
                habiButton.configuration = habiConfiguration
                habiButton.accessibilityLabel = String(localized: "Ask Habi", comment: "Opens the assistant.")

                var filterConfiguration = UIButton.Configuration.filled()
                filterConfiguration.image = .filter
                filterConfiguration.title = String(localized: "Filter", comment: "Filters the list.")
                filterButton.configuration = filterConfiguration

                2️⃣menuButton.configuration?.image = UIImage(systemName: "ellipsis")

                var shareConfiguration = UIButton.Configuration.plain()
                shareConfiguration.image = .share
                let shareButton = 3️⃣UIButton(configuration: shareConfiguration)
                addSubview(shareButton)
            }
        }
        """)
    }

    @Test func reportsImageOnlyBarButtonItems() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class DetailsViewController: UIViewController {
            private var backBarButtonItem: UIBarButtonItem?

            override func viewDidLoad() {
                super.viewDidLoad()
                backBarButtonItem = 1️⃣UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(back))
                let shareItem = UIBarButtonItem(image: .share, style: .plain, target: self, action: #selector(share))
                shareItem.accessibilityLabel = String(localized: "Share", comment: "Shares the habit.")
                let editItem = UIBarButtonItem(image: .pencil, style: .plain, target: self, action: #selector(edit))
                editItem.title = String(localized: "Edit", comment: "Edits the habit.")
                let doneItem = UIBarButtonItem(title: String(localized: "Done", comment: "Closes the screen."), image: .check20)
                navigationItem.rightBarButtonItems = [2️⃣UIBarButtonItem(image: .more, style: .plain, target: self, action: #selector(more)), shareItem, editItem, doneItem]
            }

            func makeItem() -> UIBarButtonItem {
                return UIBarButtonItem(image: .more, style: .plain, target: self, action: #selector(more))
            }
        }
        """, messages: [
            "1️⃣": "`backBarButtonItem` shows only an image, so VoiceOver can only read the image's name. "
                + "Set its `accessibilityLabel` to a localized description of what it does.",
            "2️⃣": "This bar button item shows only an image, so VoiceOver can only read the image's name. "
                + "Set its `accessibilityLabel` to a localized description of what it does.",
        ])
    }

    @Test func acceptsALabelSetOnTheSameButtonThroughAnotherType() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class Header: UIView {
            let closeButton = UIButton()

            func localize() {
                closeButton.accessibilityLabel = String(localized: "Close", comment: "Closes the screen.")
            }
        }

        final class ScreenViewController: UIViewController {
            private let header = Header()

            override func viewDidLoad() {
                super.viewDidLoad()
                header.closeButton.setImage(.close24, for: .normal)
            }
        }
        """)
    }

    @Test func skipsDebugCode() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class DebugViewController: UIViewController {
            private let resetButton = UIButton()

            override func viewDidLoad() {
                super.viewDidLoad()
                #if DEBUG
                    resetButton.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
                #endif
            }
        }
        """)
    }

    @Test func usesTheConfiguredLabelProperties() {
        assertLint(UnlabeledImageButtonRule.self, options: "label_properties: [voiceOverName]", """
        final class SelectionBar: UIView {
            private let endButton = UIButton()
            private let doneButton = UIButton()

            func configure() {
                endButton.setImage(.close24, for: .normal)
                endButton.voiceOverName = String(localized: "Cancel", comment: "Ends selecting habits.")
                1️⃣doneButton.setImage(.check20, for: .normal)
                doneButton.accessibilityLabel = String(localized: "Done", comment: "Completes the habits.")
            }
        }
        """)
    }
}

@Suite struct UnlabeledImageButtonLocalTests {
    @Test func tracksOnlyButtonsCreatedLocally() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class PlayerViewController: UIViewController {
            @objc private func togglePlayback() {
                guard let button = view.viewWithTag(1) as? UIButton else { return }
                button.setImage(UIImage(systemName: "pause"), for: .normal)
                let current = toolbarButtons[0]
                current.setImage(UIImage(systemName: "play"), for: .normal)
                let made = makeButton()
                made.setImage(.dot, for: .normal)
                let created = UIButton.init(type: .system)
                1️⃣created.setImage(.dot, for: .normal)
                let system = UIButton(type: .system)
                2️⃣system.setImage(.dot, for: .normal)
            }
        }
        """)
    }

    @Test func acceptsALabelSetByTheTypeThatOwnsTheButton() {
        assertLint(UnlabeledImageButtonRule.self, """
        final class HabitCell: UICollectionViewCell {
            let actionButton = UIButton()

            func configure(habit: Habit) {
                actionButton.accessibilityLabel = habit.actionTitle
            }
        }

        final class HabitsViewController: UICollectionViewController {
            override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "habit", for: indexPath) as! HabitCell
                cell.actionButton.setImage(.check20, for: .normal)
                return cell
            }
        }
        """)
    }
}
