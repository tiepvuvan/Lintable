# Rules

| Rule | Category | Summary |
|---|---|---|
| [`english_plural_logic`](english_plural_logic.md) | Localization | Code picks a singular or plural word by comparing a count with 1. |
| [`hardcoded_ui_text`](hardcoded_ui_text.md) | Localization | A string literal reaches UI text without being localized. |
| [`invalid_directive`](invalid_directive.md) | Lintable | A `// lintable:` comment that isn't a valid directive. |
| [`layout_lifecycle`](layout_lifecycle.md) | UIKit and AppKit layout | Views get geometry only during layout: set `frame`, `bounds`, `center` or a layer's `position` in `layoutSubviews()` and its relatives, not in gesture handlers, callbacks or setters. |
| [`localized_concatenation`](localized_concatenation.md) | Localization | Text built by joining localized pieces. |
| [`missing_package_string`](missing_package_string.md) | Localization | A target's String Catalog lacks a string that a package it links reads from the target's bundle. |
| [`missing_plural_form`](missing_plural_form.md) | Localization | A plural variation lacks a form its language needs. |
| [`missing_reason`](missing_reason.md) | Lintable | A directive has no reason after ` - `. |
| [`missing_translation`](missing_translation.md) | Localization | A string has no finished translation in one of the String Catalog's languages. |
| [`missing_translator_comment`](missing_translator_comment.md) | Localization | A String Catalog key has no comment for translators. |
| [`number_as_text_in_localized_string`](number_as_text_in_localized_string.md) | Localization | A localized string interpolates a number already turned into text. |
| [`number_without_plural`](number_without_plural.md) | Localization | An English source string counts something without varying by plural. |
| [`placeholder_mismatch`](placeholder_mismatch.md) | Localization | A translation's format specifiers don't match the source string's. |
| [`plural_form_without_number`](plural_form_without_number.md) | Localization | A plural form is used for several numbers but doesn't show the number. |
| [`stale_string`](stale_string.md) | Localization | A String Catalog keeps a string the code no longer uses. |
| [`superfluous_directive`](superfluous_directive.md) | Lintable | A directive suppresses no violation. |
| [`unknown_rule`](unknown_rule.md) | Lintable | A directive names a rule that isn't loaded. |
| [`unlabeled_image_button`](unlabeled_image_button.md) | Accessibility | A button shows only an image and has no accessibility label. |
