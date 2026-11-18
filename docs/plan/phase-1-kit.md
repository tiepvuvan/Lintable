# Phase 1: `LintableKit`

Build the rule API and the syntax index that every rule uses. This is the
public surface rule authors depend on, so it gets the most care.

Read first: [architecture.md](architecture.md), "The rule API" and "The syntax
index"; [rules/layout_lifecycle.md](rules/layout_lifecycle.md), the first
consumer of the index.

## Files

```
Sources/LintableKit/
  Rule.swift
  RuleOptions.swift
  RuleDescription.swift
  RuleID.swift
  Severity.swift
  Example.swift
  Violation.swift
  RulePack.swift
  LintFile.swift
  Index/SyntaxIndex.swift
  Index/Scope.swift
  Index/FunctionSignature.swift
  Index/TypeContext.swift
  Index/CallSites.swift
  Index/AssignmentTarget.swift
  Index/ClosureInvocation.swift
  Index/LocalVariables.swift
  LintableKit.docc/
Tests/LintableKitTests/
```

## Steps

1. **API types** exactly as in architecture.md: `Rule`, `RuleOptions`,
   `NoOptions`, `RuleDescription`, `RuleID`, `RuleCategory`, `Severity`,
   `Example`, `Violation`, `Note`, `RulePack`, `LintFile`.
2. **`Example`.** Holds marked source. `Example.parse()` returns the source with
   markers removed and the marker positions in order. Phase 3's harness and the
   docs generator use it.
3. **`LintFile`.** Created from a path and source text: parses with
   `Parser.parse(source:)`, keeps the tree and a `SourceLocationConverter`, and
   owns its `SyntaxIndex`. Line and column conversion lives here, so rules never
   do it.
4. **`SyntaxIndex`.** Built on first use, in one pass over the tree, and
   immutable after that, so rules can query it from any task:
   - **Scopes:** function, initializer, deinitializer, subscript, accessor
     (`get`, `set`, `willSet`, `didSet`, `init` accessors), closure, top level.
     `scope(of:)` and `scopes(of:)`.
   - **Signatures:** base name, argument labels (`layoutSublayers(of:)`),
     `override`, `static`/`class`, access level (explicit, or the default from
     the enclosing extension's modifier), attributes.
   - **Types:** kind, name, generic parameters left out, the inheritance clause
     as written, and `inheritsFrom(_:anyOf:)`, which also follows a superclass
     declared in the same file.
   - **Calls and references:** `calls(to:)` matches `f(…)`, `self.f(…)`,
     `x.f(…)` and trailing-closure forms by base name and labels.
     `references(to:)` finds `#selector(f)`, `#selector(Type.f)` and `f` used as
     a value.
   - **Closures:** `invocation(of:)` names the call a closure is passed to, as a
     dotted chain (`DispatchQueue.main.async`), whether it's a trailing closure
     or a labelled argument.
   - **Assignments:** `assignmentTarget(of:)` turns `a.b.frame.origin.x = …` into
     root `a`, members `[b, frame, origin, x]`; `frame = …` into implicit `self`
     with members `[frame]`; and handles compound operators.
   - **Locals:** `localVariable(named:at:)` tells whether a name is a local
     declared earlier in the same scope, including `if let`, `guard let`, `for`
     and closure parameters.
5. **DocC.** An overview article ("Writing a rule") and an entry for every public
   symbol, written as symbol extension files in `LintableKit.docc`.

## Tests

One suite per index query, with small fixtures as string literals. At least:

- Scopes: a write in a `didSet` reports the accessor; in a closure in a function,
  the closure then the function; at top level, top level.
- Signatures: `func f(_ a: Int, of b: Int)` is `f(_:of:)`; `private extension`
  makes members private; `override` and `@objc` are seen.
- Types: nested types; an extension's type name; `inheritsFrom` through a
  same-file superclass; a protocol in the inheritance clause doesn't confuse it.
- Calls: plain, `self.`, member, trailing closure, and a same-name function with
  different labels not matching.
- References: `#selector(handle(_:))`, `#selector(Self.handle)`,
  `button.addAction(UIAction(handler: handle))`.
- Closures: trailing and labelled closures to `DispatchQueue.main.async`,
  `Task { }`, `asyncAfter(deadline:execute:)`.
- Assignments: explicit and implicit `self`, optional chaining (`a?.frame = …`),
  compound operators, a tuple assignment ignored.
- Locals: shadowing by `var frame`, by a `guard let`, and a parameter.

## Verify

```bash
swift test --filter LintableKitTests
```

```bash
swift build -c release
```

The DocC catalog builds: `swift package generate-documentation --target LintableKit`
(add the swift-docc-plugin as a dependency only if this needs it; otherwise use
`xcodebuild docbuild`).

## Done

The API compiles in Swift 6 mode with strict concurrency, every query is tested,
every public symbol is documented, CI is green. One commit.
