# Phase 3: the test harness and rule docs

Build `LintableTesting`, which Lintable's rules and every custom rule pack use to
test themselves, and generate each rule's documentation from its description.

Read first: [architecture.md](architecture.md), "The rule API" (examples and
markers); phase 1's `Example`.

## Files

```
Sources/LintableTesting/
  AssertLint.swift
  VerifyExamples.swift
  LintableTesting.docc/
Sources/LintableEngine/Docs/RuleDocsGenerator.swift
Sources/LintableCommand/ExplainCommand.swift
Sources/LintableCommand/DocsCommand.swift
Tests/LintableTestingTests/
```

## Steps

1. **`assertLint`.**

   ```swift
   assertLint(
       LayoutLifecycleRule.self,
       options: .init(),
       """
       final class ChartView: UIView {
           @objc private func pan() {
               1️⃣frame = .zero
           }
       }
       """,
       messages: ["1️⃣": "`frame` is set in `pan()`, outside the layout pass. …"]
   )
   ```

   It parses the markers, runs the rule through the engine (so directives
   apply), and records a Swift Testing issue at the caller's source location for
   every missing, extra or misplaced violation, showing expected and actual
   positions in the source. `messages` is optional; positions are always
   checked.
2. **`verifyExamples(of:)`.** For one rule type:
   - every triggering example has violations exactly at its markers;
   - every non-triggering example has none;
   - adding `// lintable:disable:next <id> - test` before each marked line
     silences it, which proves the rule reports on the line it points to;
   - every example parses without syntax errors.
3. **Docs generator.** Renders one Markdown page per rule: summary, rationale,
   category, default severity, an options table (from a `Codable` reflection of
   `Options()`, with each option's description from the rule), triggering and
   non-triggering examples with markers removed. Plus an index page listing all
   rules. Rules can add a longer "How to fix" section through their description.
4. **Commands.** `lintable explain <id>` prints the page for one rule to the
   terminal; `lintable docs --output docs/rules` writes all pages.
5. **CI.** Regenerate `docs/rules` and fail when it differs from what's
   committed.

## Tests

- `assertLint` reports a missing violation, an extra one and one at the wrong
  column, each at the test's source location (use `withKnownIssue` to check
  failures are recorded).
- `verifyExamples` passes for a correct test rule and fails for one whose
  example markers are off by a line.
- The docs generator's output for a test rule matches a golden file.

## Verify

```bash
swift test --filter LintableTestingTests
```

```bash
swift run lintable docs --output docs/rules
```

## Done

Rule authors can test a rule in a few lines, examples are verified, rule pages
are generated and checked in CI. One commit.
