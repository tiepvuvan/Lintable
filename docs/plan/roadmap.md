# After 0.4.0

Ideas, not commitments. Each new rule starts as a rule proposal issue and has to
meet the bar in [README.md](README.md).

## Engine

- **Module rules** (architecture.md, "Extension points kept open"): facts
  collected per file in parallel, analyzed per module. Unlocks rules about how
  functions and types are used across files.
- **Fix-its** and `lintable fix`, for rules whose fix is mechanical.
- **Per-directory configs** that refine a parent config, for monorepos.
- **Homebrew** formula, a Swift Package Index listing, and the DocC docs hosted
  on GitHub Pages.

## Rule candidates

All need structure that line-based rules can't see reliably:

- **`view_hierarchy_lookup`**: a view or view controller walking up its parents,
  presenters, superviews or responder chain to find its owner, or searching
  children by type. Habitify enforces this today with two regex rules; a
  syntactic version can tell a loop step from a single read.
- **`state_change_in_body`**: a SwiftUI `body` (or a `@ViewBuilder` it calls)
  assigning to `@State`, `@Binding` or an observed object's property.
- **`task_without_cancellation`**: a `Task { }` started in a view or view
  controller lifecycle method and never stored or cancelled.
- **`notification_observer_lifetime`**: a block-based
  `NotificationCenter.addObserver` whose token is dropped.
- **`assertion_without_report`**: `assertionFailure` with no call to a configured
  reporting function in the lines before it (Habitify's `AppLog.critical`
  convention, made general through an option).
