# Writing a rule

Describe the rule, give it options, walk the file, and test it with examples.

## Describe it

``RuleDescription`` holds everything Lintable shows about a rule: its snake_case
``RuleID``, a one-line summary, the rationale, the default ``Severity``, a description of
each option, and examples. Mark where violations are expected with `1️⃣`, `2️⃣`, …: the
examples are the rule's documentation page and its first tests.

## Give it options

Options are a ``RuleOptions`` struct whose properties all have defaults. Lintable decodes
the rule's section of `.lintable.yml` into it, with snake_case keys, and refuses unknown
keys. Don't use optional properties: an option that's unset is its default.

## Check a file

``Rule/check(_:)`` receives a ``LintFile``. Walk ``LintFile/tree`` with a
`SyntaxVisitor`, ask ``LintFile/index`` about what you find, and return a ``Violation``
for each problem. Report at the node the reader should look at; Lintable turns positions
into lines and columns, applies `// lintable:` directives, and formats the output.

Rules run on many files at once, so they must not keep mutable state.

## Ship it

Group rules in a ``RulePack`` and pass the pack to `LintableCommand.main(rulePacks:)`.
Test every rule with `LintableTesting`'s `verifyExamples(of:)` and `assertLint`.
