# Contributing to Lintable

Thanks for helping. Lintable is for rules that need code structure: the function,
accessor or closure around a line, the type it's in, and what calls what in a file.
Style and formatting rules belong in SwiftLint or swift-format.

## Build, test, lint

```bash
swift build
```

```bash
swift test
```

```bash
swiftlint lint --strict
```

CI runs all three on macOS, and build and test on Linux.

## Conventions

- Swift 6 language mode with strict concurrency.
- No comments in Swift code. Only `// swiftlint:` and `// lintable:` directives are
  allowed. Make the code explain itself with names and small functions; document
  public API in the target's DocC catalog (`Sources/<Target>/<Target>.docc`).
- No force unwraps or force casts outside tests.
- Tests use Swift Testing. Rules are tested with `LintableTesting`: `assertLint` with
  `1️⃣` markers, and `verifyExamples(of:)` for every rule.

## Proposing a rule

Open a **Rule proposal** issue before writing code. A rule belongs here when:

- it needs structure that a line-based regex can't see reliably;
- its rationale fits in a paragraph, with a clear "do this instead";
- it has few false positives on real code, and the ones it has can be explained and
  suppressed with a reason;
- its defaults suit most projects, and options cover the rest.

## A rule's checklist

- A spec: what it reports, where it's allowed, its messages and options.
- Options with defaults for everything, as a `RuleOptions` struct.
- Triggering and non-triggering examples in its `RuleDescription`, with markers.
- Tests: `verifyExamples(of:)` plus `assertLint` cases for every context and option.
- A "How to fix" section in its description, and its generated page in `docs/rules`.
- A run on a real codebase, with the false positives explained in the pull request.
