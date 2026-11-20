# `hardcoded_ui_text`

**Hard-coded UI text** · Localization · default severity: warning

A string literal reaches UI text without being localized.

## Rationale

A literal assigned to a label's `text`, a controller's `title`, an alert's title or an accessibility label shows English to everyone, and no String Catalog lists it, so no translation check can see it. The rule reports literals that look like text, with letters and a space or a capital letter, in those places, and in `Text(verbatim:)`. Code inside `#if DEBUG`, `#Preview` and `PreviewProvider` types is skipped. For text that stays English on purpose, add `// lintable:disable:next hardcoded_ui_text - <reason>`.

## Options

| Option | Default | Meaning |
|---|---|---|
| `calls` | `UIAlertController(title:)`, `UIAlertController(message:)`, `UIAlertAction(title:)`, `UIBarButtonItem(title:)`, `UIAction(title:)`, `UIMenu(title:)`, `UIContextualAction(title:)`, `setTitle(_:)`, `NSAttributedString(string:)` | Calls whose argument shows text, written `Name(label:)`, or `name(_:)` for the first unlabeled argument. |
| `check_verbatim_text` | `true` | Also report `Text(verbatim:)` with text that has several words. |
| `properties` | `text`, `title`, `subtitle`, `body`, `placeholder`, `prompt`, `secondaryText`, `accessibilityLabel`, `accessibilityHint`, `accessibilityValue` | Properties whose assignment shows text, on any type. |

## How to fix

Wrap the text in `String(localized: "…", comment: "…")`, or use the SwiftUI initializer that takes a `LocalizedStringKey`, such as `Text("…")`.

## Reported

```swift
func configure() {
    picker.title = ↓"Select Time"
    let alert = UIAlertController(title: ↓"Oops!", message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: ↓"OK", style: .default))
    button.setTitle(↓"Done", for: .normal)
}
```

```swift
var body: some View {
    Text(verbatim: ↓"Your day, beautifully organized")
}
```

## Not reported

```swift
func configure() {
    picker.title = String(localized: "Select Time", comment: "Title of the time picker.")
    cell.accessibilityIdentifier = "habitCell"
    label.text = "%"
    Text(verbatim: "•")
    #if DEBUG
        debugLabel.text = "Debug build"
    #endif
}
```
