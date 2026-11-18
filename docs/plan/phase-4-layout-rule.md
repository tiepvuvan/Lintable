# Phase 4: `layout_lifecycle`

Build the first rule, test it, write its documentation page, and check it
against a real codebase: Habitify, the first adopter.

Read first: [rules/layout_lifecycle.md](rules/layout_lifecycle.md) (the spec;
it is the source of truth), [architecture.md](architecture.md), phase 1's index
and phase 3's harness.

## Files

```
Sources/LintableRules/LintableRules.swift
Sources/LintableRules/LayoutLifecycle/LayoutLifecycleRule.swift
Sources/LintableRules/LayoutLifecycle/LayoutLifecycleOptions.swift
Sources/LintableRules/LayoutLifecycle/LayoutLifecycleVisitor.swift
Sources/LintableRules/LayoutLifecycle/LayoutLifecycleRule+Description.swift
Sources/LintableRules/LintableRules.docc/
Tests/LintableRulesTests/LayoutLifecycleRuleTests.swift
docs/rules/layout_lifecycle.md
```

## Steps

1. **Pack.** `LintableRules: RulePack` with `rules = [LayoutLifecycleRule.self]`.
2. **Options.** `LayoutLifecycleOptions` with the fields and defaults from the
   spec's options table.
3. **Rule.** In one walk of the file:
   - collect layout writes (spec: "What counts as a layout write");
   - collect calls to layout helpers;
   - for each, decide the context with the index: layout method, transition
     method (when exempt), exempt superclass, or a closure handed to a deferred
     call;
   - helpers: a private or fileprivate `<prefix><Uppercase>` function is allowed
     when every call to it in the file comes from an allowed context and it has
     no references (`#selector`, value use) and no `@objc`. Report a call from
     anywhere else at the call, and a non-private one at its declaration;
   - emit the spec's messages, each ending with the documentation link.
4. **Description.** Summary, rationale, category, default severity, the spec's
   examples (plus one per allowed context and one per message), and the "How to
   fix" section with before-and-after code for each recipe in the spec.
5. **Docs.** Run `lintable docs` and commit `docs/rules/layout_lifecycle.md`.

## Tests

`verifyExamples(of: LayoutLifecycleRule.self)`, plus `assertLint` cases for at
least:

- Allowed: each UIKit, AppKit and Core Animation layout method; each transition
  method; `apply(_:)` on a cell; a write inside `UIView.performWithoutAnimation`
  in `layoutSubviews()`; a private `layoutX()` called only from layout; a helper
  calling another helper; `attributes.frame` in a `UICollectionViewLayout`
  subclass and in a subclass of that subclass declared in the same file.
- Reported: a gesture handler; `viewDidLoad()`; `init`; a `didSet`; a public
  setter; a `UIView.animate` block in a button action; a closure passed to each
  default deferred call inside `layoutSubviews()`; a transition method when
  `exempt_transitions` is `false`.
- Helpers: a helper also called from an action (the call is reported, its
  writes aren't); a non-private `layoutX()`; a helper used in `#selector`; an
  `@objc` helper; a function named `layout` alone (not a helper); `layoutbar()`
  (lowercase after the prefix, not a helper).
- Writes: `center.x`, `frame.origin.y +=`, `bounds.size`, a layer's `position`
  and `anchorPoint`, optional chaining (`view?.frame = …`), implicit `self`.
- Not writes: a local `var frame`; `transform` by default (reported when
  `check_transform` is `true`); an implicit-`self` write inside a struct;
  SwiftUI's `.frame(width:height:)`; a comparison (`frame == .zero`).
- Options: custom `properties`, `layout_methods`, `exempt_superclasses`,
  `helper_prefix`, `deferred_calls`.

## Validate on Habitify

Habitify (`../habitify-ios-mac` in a local checkout) has a hand-checked
inventory of every site, kept in its private adoption plan. Its repository is
private, so this step is done by someone with access to both. With a temporary
config enabling the rule:

```bash
swift run -c release lintable lint --config /tmp/lintable-habitify.yml --reporter json ../habitify-ios-mac > /tmp/habitify-layout.json
```

- Nothing is reported on collection view layout attributes, transition code, or
  the local `frame` variable (groups A and B in Habitify's inventory, 29 writes).
- Every site in its group C is reported (29 writes in 23 functions, plus 3 layer
  `position` writes), possibly with a few more found by the stricter syntax
  analysis. Explain each difference; fix the rule or report it to Habitify's
  inventory.
- Record the counts, any false positives and their causes, and the cold and
  cached run times in [facts.md](facts.md). Keep Habitify's file names out of
  this public repo: counts and kinds only.

## Verify

```bash
swift test --filter LintableRulesTests
```

```bash
swift run lintable explain layout_lifecycle
```

## Done

The rule matches the spec, its tests and examples pass, its page is generated,
and the Habitify validation is recorded with no unexplained differences. One
commit.
