# Rules

| Rule | Category | Summary |
|---|---|---|
| [`invalid_directive`](invalid_directive.md) | Lintable | A `// lintable:` comment that isn't a valid directive. |
| [`layout_lifecycle`](layout_lifecycle.md) | UIKit and AppKit layout | Views get geometry only during layout: set `frame`, `bounds`, `center` or a layer's `position` in `layoutSubviews()` and its relatives, not in gesture handlers, callbacks or setters. |
| [`missing_reason`](missing_reason.md) | Lintable | A directive has no reason after ` - `. |
| [`superfluous_directive`](superfluous_directive.md) | Lintable | A directive suppresses no violation. |
| [`unknown_rule`](unknown_rule.md) | Lintable | A directive names a rule that isn't loaded. |
