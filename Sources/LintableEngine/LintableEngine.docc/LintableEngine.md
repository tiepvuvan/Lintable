# ``LintableEngine``

Configuration, file discovery, running rules, directives, baselines, the cache and
reporters.

## Overview

``Configuration`` reads `.lintable.yml` against a ``RuleRegistry`` of loaded rule packs.
``Linter`` checks files in parallel, applies `// lintable:` directives through
``DirectiveProcessor``, drops ``Baseline`` entries, and uses a ``Cache`` keyed by the
tool version, the rules, the config and each file's content. A ``Reporter`` turns the
``LintResult`` into output.

## Topics

### Running

- ``Configuration``
- ``ConfigurationError``
- ``RuleRegistry``
- ``ConfiguredRule``
- ``Linter``
- ``LintResult``
- ``ReportedViolation``
- ``FileDiscovery``
- ``Glob``

### Directives

- ``Directive``
- ``DirectiveParser``
- ``DirectiveProcessor``
- ``EngineRules``

### Results

- ``Baseline``
- ``Cache``
- ``Reporter``
- ``Reporters``
