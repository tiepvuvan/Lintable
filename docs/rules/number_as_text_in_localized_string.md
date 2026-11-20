# `number_as_text_in_localized_string`

**Number as text in a localized string** · Localization · default severity: warning

A localized string interpolates a number already turned into text.

## Rationale

`String(localized: "\(count) habits")` reaches the String Catalog as `%lld habits`, which can vary by plural. `"\(String(count)) habits"` or `"\(count.description) habits"` reaches it as `%@ habits`, which can't, so every language shows one form for every number. The rule reports `String(…)`, `String(describing:)` and `.description` of a value named like a count, such as `count`, `total` or `streakLength`, interpolated into `String(localized:)`, `Text("…")`, `LocalizedStringKey`, `LocalizedStringResource` and `AttributedString(localized:)`.

## How to fix

Interpolate the number itself: `String(localized: "\(count) habits", comment: "…")`.

## Reported

```swift
let title = String(localized: "\(↓String(count)) habits", comment: "Number of habits.")
```

```swift
Text("\(↓streak.description) day streak")
```

## Not reported

```swift
let title = String(localized: "\(count) habits", comment: "Number of habits.")
let summary = "\(String(count))/\(total)"
let name = String(localized: "\(String(title.characters)) note", comment: "A note's title.")
```
