# `stale_string`

**Stale string** · Localization · default severity: warning

A String Catalog keeps a string the code no longer uses.

## Rationale

Xcode marks a key stale when the code stops using it, and keeps it with its translations in case it comes back. Stale keys make translators work on text nobody sees and make catalogs harder to review.

## How to fix

Delete the string from the catalog. If the code builds the key at run time, which Xcode can't see, set its extraction state to `manual` instead.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"Old onboarding title" : {
      "extractionState" : "stale",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Alter Titel" } }
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
    "Welcome" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Willkommen" } }
      }
    }
  },
  "version" : "1.0"
}
```
