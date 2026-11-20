# Phase 6: custom rule packages, release 0.4.0

Make it easy for a project to write its own rules and run them in its builds,
next to the built-in ones.

Read first: [architecture.md](architecture.md), "Custom rules"; phase 3's
harness; phase 5's plugins and bundle script.

## Files

```
Templates/CustomLinter/Package.swift
Templates/CustomLinter/Sources/AcmeRules/AcmeRules.swift
Templates/CustomLinter/Sources/AcmeRules/NoPrintInViewsRule.swift
Templates/CustomLinter/Sources/acme-lint/main.swift
Templates/CustomLinter/Tests/AcmeRulesTests/NoPrintInViewsRuleTests.swift
Templates/CustomLinter/Plugins/AcmeLintSourcePlugin/Plugin.swift
Templates/CustomLinter/Plugins/AcmeLintBinaryPlugin/Plugin.swift
Templates/CustomLinter/.lintable.yml
docs/custom-rules.md
```

## Steps

1. **Template package.** A working custom linter: a rule pack with one example
   rule that uses the index (no `print` inside a `UIView` subclass's methods),
   its tests with `LintableTesting`, and `acme-lint`, which calls
   `LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])`.
2. **Source plugin.** `AcmeLintSourcePlugin` runs the template's own executable
   as a build command: inputs are the target's Swift files and the config,
   output is a stamp file in the work directory, so it reruns only when they
   change.
3. **Binary plugin.** `AcmeLintBinaryPlugin`, the same shape as
   `LintablePlugins`, for a project that releases its linter as an artifact
   bundle.
4. **Bundle scripts.** Make `script/build-binary.sh` and `script/assemble-artifact-bundle.sh` take the executable
   product and package path, so a custom linter uses the same script.
5. **Guide** (`docs/custom-rules.md`): when a rule belongs in a project and when
   to propose it upstream; writing a rule (visitor, index queries, options,
   messages, examples); testing it; packaging it; running it from source or
   prebuilt, with the trade-off (a clean build compiles swift-syntax from
   source).
6. **CI.** Build and test the template against the local Lintable sources (path
   dependency), and run its source plugin on a fixture target.
7. **Release.** `CHANGELOG.md` 0.4.0, and with Peter's go-ahead, tag `v0.4.0`.

## Verify

```bash
cd Templates/CustomLinter && swift test
```

```bash
cd Templates/CustomLinter && swift run acme-lint rules
```

The output lists both `layout_lifecycle` and the template's rule.

## Done

A project can copy the template, write a rule, test it and run it in its build,
from source or prebuilt, following one guide. 0.4.0 is released. One commit.
