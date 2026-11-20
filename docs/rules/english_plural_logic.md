# `english_plural_logic`

**English plural logic** · Localization · default severity: warning

Code picks a singular or plural word by comparing a count with 1.

## Rationale

`count == 1 ? "day" : "days"` and `"day\(count == 1 ? "" : "s")"` hard-code English grammar. Russian needs a different word for 1, 2–4 and 5–20, Arabic six forms, and Japanese none, and translators never see these words. The rule reports a ternary that compares with 1 or 2 and chooses between two string literals.

## How to fix

Use one localized string with the number, `String(localized: "\(count) days", comment: "…")`, and vary it by plural in the String Catalog.

## Reported

```swift
func label(for count: Int) -> String {
    "\(count) day\(↓count == 1 ? "" : "s")"
}
```

```swift
let unit = ↓habits.count > 1 ? "habits" : "habit"
```

## Not reported

```swift
func label(for count: Int) -> String {
    String(localized: "\(count) days", comment: "A number of days; varies by plural in the String Catalog.")
}
```

```swift
let icon = count == 1 ? Icon.single : Icon.many
```
