# `placeholder_mismatch`

**Placeholder mismatch** · Localization · default severity: error

A translation's format specifiers don't match the source string's.

## Rationale

Foundation fills a translation's specifiers with the arguments the code passes for the source string. A translation that reads an integer as an object, `%@` where the source has `%lld`, crashes; one that drops or adds an argument shows the wrong value. The rule compares the kind of argument each position reads in the source and in every translation, using the `other` form of plural variations and the format specifier of substitutions. Integer widths such as `%d`, `%ld` and `%lld` count as the same kind.

## How to fix

Use the source's specifiers in the translation, with positions such as `%1$@` when the order changes.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "%lld habits" : {
      "localizations" : {
        ↓"de" : { "stringUnit" : { "state" : "translated", "value" : "%@ Gewohnheiten" } }
      }
    }
  },
  "version" : "1.0"
}
```

## Not reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "%1$@ has %2$lld habits" : {
      "localizations" : {
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "%2$lld 個の習慣が %1$@ にあります" } }
      }
    }
  },
  "version" : "1.0"
}
```
