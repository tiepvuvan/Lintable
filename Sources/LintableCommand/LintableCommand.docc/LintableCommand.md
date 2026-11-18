# ``LintableCommand``

The `lintable` command line, as a library.

## Overview

Call `LintableCommand.main(rulePacks:)` from an executable to get the whole CLI, with
`lint`, `baseline`, `rules`, `init` and `version`, running the rule
packs you pass. The official `lintable` executable passes `BuiltInRules`; a custom
linter passes its own packs too.

```swift
import LintableCommand
import LintableRules

await LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])
```
