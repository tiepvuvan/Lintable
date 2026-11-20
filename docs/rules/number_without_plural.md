# `number_without_plural`

**Number without plural** · Localization · default severity: warning

An English source string counts something without varying by plural.

## Rationale

“%lld records” reads “1 records” when the number is 1, and translators rarely add plural forms the source doesn't have. The rule looks at String Catalogs whose source language is English. It reports a string with no plural variation where an integer placeholder is followed by a word that looks plural, directly or after one other word. Numbers inside `^[…](inflect: true)` are left to Foundation's automatic grammar agreement.

## Options

| Option | Default | Meaning |
|---|---|---|
| `ignored_keys` | none | Keys to skip, such as one that only ever shows numbers above 1. |
| `ignored_words` | none | Words ending in s after a number that aren't plurals in your strings. |

## How to fix

Vary the string by plural in Xcode's String Catalog editor (one: “%lld record”, other: “%lld records”), or rephrase it so the number doesn't count a noun, such as “Records: %lld”.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"%lld records" : {
    },
    ↓"%1$lld of %2$lld days complete" : {
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
    "%lld this week" : {
    },
    "Step %1$lld of %2$lld" : {
    },
    "Best: ^[%lld days](inflect: true)" : {
    },
    "%lld habits" : {
      "localizations" : {
        "en" : {
          "variations" : {
            "plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld habit" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld habits" } }
            }
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```
