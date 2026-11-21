# `unlabeled_image_button`

**Unlabeled image button** · Accessibility · default severity: warning

A button shows only an image and has no accessibility label.

## Rationale

VoiceOver reads a button's title. A button that shows only an image has none, so VoiceOver falls back to the image's name: a VoiceOver user hears "Close24" or "ellipsis" instead of what the button does. The rule reports SwiftUI buttons, links and menus whose label holds only images, with no `Text` or `Label` and no `.accessibilityLabel(...)` on the control or the image. It also reports UIKit buttons that get an image through `setImage(_:for:)` or a `UIButton.Configuration`, and `UIBarButtonItem(image:)` items, that never get a title or an accessibility label in the type that configures them and its extensions in the same file. A local button is followed into the property it's stored in, including a `lazy var` initialized by a closure. Buttons that set their own image in a `UIButton` subclass, buttons passed in as parameters and buttons returned from a function are left to the code that uses them. Code inside `#if DEBUG`, `#Preview` and `PreviewProvider` types is skipped.

## Options

| Option | Default | Meaning |
|---|---|---|
| `label_modifiers` | `accessibilityLabel`, `accessibilityRepresentation` | SwiftUI modifiers that give a control an accessibility label. |
| `label_properties` | `accessibilityLabel`, `accessibilityAttributedLabel`, `title` | UIKit properties whose assignment gives a button or bar button item an accessibility label. |
| `swiftui_controls` | `Button`, `Link`, `Menu`, `NavigationLink` | SwiftUI controls whose image-only label needs an accessibility label. |

## How to fix

Give the button a short localized description of what it does, not of what the image shows: "Close", not "X". In SwiftUI, add `.accessibilityLabel(Text("Close", comment: "…"))` to the button, or use `Button("Close", systemImage: "xmark", action: …)` with `.labelStyle(.iconOnly)` to keep the image-only look. In UIKit, set `accessibilityLabel` to a `String(localized:comment:)`. A button that VoiceOver should skip takes `isAccessibilityElement = false`.

## Reported

```swift
struct OfferCard: View {
    var body: some View {
        ↓Button(action: dismiss) {
            Image(.close24)
        }
    }
}
```

```swift
final class SelectionBar: UIView {
    private let endButton = UIButton()

    func configure() {
        ↓endButton.setImage(.close24, for: .normal)
    }
}
```

```swift
final class DetailsViewController: UIViewController {
    lazy var menuButton: UIButton = {
        let button = UIButton()
        ↓button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = ↓UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(back))
    }
}
```

## Not reported

```swift
struct OfferCard: View {
    var body: some View {
        Button(action: dismiss) {
            Image(.close24)
        }
        .accessibilityLabel(Text("Close", comment: "Button that closes the offer."))
        Button("Done", systemImage: "checkmark", action: save)
        Button(action: share) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}
```

```swift
final class SelectionBar: UIView {
    private let endButton = UIButton()
    private let completeButton = UIButton()

    func configure() {
        endButton.setImage(.close24, for: .normal)
        endButton.accessibilityLabel = String(localized: "Cancel", comment: "Button that ends selecting habits.")
        completeButton.setImage(.check20, for: .normal)
        completeButton.setTitle(String(localized: "Complete", comment: "Button that completes the selected habits."), for: .normal)
    }
}
```
