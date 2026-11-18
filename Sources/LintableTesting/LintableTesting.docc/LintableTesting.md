# ``LintableTesting``

Test rules with marked source.

## Overview

Mark expected violations with `1️⃣`, `2️⃣`, … and call `assertLint`. It runs the rule
through the engine, so directives apply, and records a Swift Testing issue at your test's
line for every missing, extra or misplaced violation, and for a message that differs from
the one you expect.

```swift
@Test func reportsWritesInGestureHandlers() {
    assertLint(LayoutLifecycleRule.self, """
    final class ChartView: UIView {
        @objc func pan() {
            1️⃣line.center.x = 0
        }
    }
    """)
}

@Test func examplesAreCorrect() {
    verifyExamples(of: LayoutLifecycleRule.self)
}
```

`verifyExamples(of:)` checks that triggering examples report exactly at their markers,
that non-triggering examples report nothing, that a `disable:next` directive before each
marked line silences it, and that every example parses.
