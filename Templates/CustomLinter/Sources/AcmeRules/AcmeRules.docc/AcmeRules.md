# ``AcmeRules``

Acme's own Lintable rules, run next to the built-in ones by `acme-lint`.

## Overview

``AcmeRules`` is a `RulePack`: a named, versioned list of rules. `acme-lint` passes it to
`LintableCommand.main(rulePacks:)` with Lintable's `BuiltInRules`, so one config,
one set of directives and one report cover both.

## Topics

### Rules

- ``NoPrintInViewsRule``
