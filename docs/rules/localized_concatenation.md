# `localized_concatenation`

**Localized concatenation** · Localization · default severity: warning

Text built by joining localized pieces.

## Rationale

`String(localized: "Completed") + " " + String(localized: "today")` and `"\(String(localized: "times")), \(String(localized: "mins"))"` keep English word order, spacing and punctuation in every language, and translators see the pieces without the sentence. The rule reports `+` between a localized string and other text, and a plain string literal that interpolates a localized string next to other text or values.

## How to fix

Localize the whole text as one string, with placeholders for the values: `String(localized: "\(name) completed today", comment: "…")`.

## Reported

```swift
let summary = ↓String(localized: "Completed", comment: "Status.") + " " + String(localized: "today", comment: "Day.")
```

```swift
let units = ↓"\(String(localized: "times", comment: "Unit.")), \(String(localized: "mins", comment: "Unit."))…"
```

## Not reported

```swift
let summary = String(localized: "Completed today", comment: "Status.")
let line = String(localized: "\(name) completed today", comment: "Status of a habit.")
let path = "\(folder)/\(file)"
```
