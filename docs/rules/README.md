# Rules

| Rule | Category | Summary |
|---|---|---|
| [`invalid_directive`](invalid_directive.md) | Lintable | A `// lintable:` comment that isn't a valid directive. |
| [`layout_lifecycle`](layout_lifecycle.md) | UIKit and AppKit layout | Views get geometry only during layout: set `frame`, `bounds`, `center` or a layer's `position` in `layoutSubviews()` and its relatives, not in gesture handlers, callbacks or setters. |
| [`missing_plural_form`](missing_plural_form.md) | Localization | A plural variation lacks a form its language needs. |
| [`missing_reason`](missing_reason.md) | Lintable | A directive has no reason after ` - `. |
| [`missing_translation`](missing_translation.md) | Localization | A string has no finished translation in one of the String Catalog's languages. |
| [`number_without_plural`](number_without_plural.md) | Localization | An English source string counts something without varying by plural. |
| [`placeholder_mismatch`](placeholder_mismatch.md) | Localization | A translation's format specifiers don't match the source string's. |
| [`plural_form_without_number`](plural_form_without_number.md) | Localization | A plural form is used for several numbers but doesn't show the number. |
| [`stale_string`](stale_string.md) | Localization | A String Catalog keeps a string the code no longer uses. |
| [`superfluous_directive`](superfluous_directive.md) | Lintable | A directive suppresses no violation. |
| [`unknown_rule`](unknown_rule.md) | Lintable | A directive names a rule that isn't loaded. |
