# `missing_translation`

**Missing translation** · Localization · default severity: warning

A string has no finished translation in one of the String Catalog's languages.

## Rationale

A key without a translation shows its source text, usually English, to everyone who uses that language. Xcode shows each catalog's completion but never fails a build over it, so new strings ship untranslated. The rule reports each string that lacks a translation in a language the catalog has, or whose translation is still marked `new` or `needs_review`. Keys Xcode marked stale, keys marked Don't Translate and empty keys are skipped.

To let Debug builds warn while release builds stop, keep the rule's severity at `warning`, give it `release_severity: error` and set the config's `release_condition`, for example `!DEBUG`.

## Options

| Option | Default | Meaning |
|---|---|---|
| `accepted_states` | `translated` | The translation states that count as finished. |
| `languages` | none | The languages every string needs. Empty means every language the catalog has. |

## How to fix

Translate the string in Xcode's String Catalog editor, or mark it Don't Translate if it reads the same in every language.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"Done" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Fertig" } }
      }
    },
    "Save" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Sichern" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Enregistrer" } }
      }
    }
  },
  "version" : "1.0"
}
```

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"Done" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "needs_review", "value" : "Fertig" } }
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
    "Done" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Fertig" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Terminé" } }
      }
    },
    "Habitify" : {
      "shouldTranslate" : false
    },
    "Old text" : {
      "extractionState" : "stale",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Alter Text" } }
      }
    }
  },
  "version" : "1.0"
}
```
