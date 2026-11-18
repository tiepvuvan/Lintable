# Lintable

Architecture rules for Swift: rules that need to know where code is, not just
what it says.

SwiftLint is great at style: what a line looks like. Some rules need more than a
line. "Set a view's frame only during layout" depends on which function the line
is in, what calls that function, and which class it belongs to. Lintable parses
Swift with [swift-syntax](https://github.com/swiftlang/swift-syntax), gives every
rule the structure around each line, and makes rules like that easy to write,
test and share.

Lintable runs next to SwiftLint, not instead of it.

> **Status: in development, not released yet.** The design and build plan are
> in [docs/plan](docs/plan/README.md). The first rule is
> [`layout_lifecycle`](docs/plan/rules/layout_lifecycle.md), and
> [Habitify](https://www.habitify.me) is the first project to adopt it.

## What it will look like

```yaml
rules:
  layout_lifecycle:
    severity: error
```

```
Sources/Chart/ChartView.swift:42:9: error: `frame` is set in `handlePan(_:)`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper. (layout_lifecycle)
```

- A build-tool plugin for Swift packages and Xcode projects, running a prebuilt
  binary, so builds don't compile swift-syntax.
- A CLI for scripts and CI, with Xcode, JSON, SARIF and GitHub Actions output.
- `// lintable:disable:next <rule> - <reason>` for exceptions, with the reason
  required.
- Baselines, so a team can adopt a rule before fixing every existing case.
- A public rule API. A project writes its own rules in its own package and
  builds a linter that combines them with Lintable's built-in rules.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Lintable is MIT-licensed.
