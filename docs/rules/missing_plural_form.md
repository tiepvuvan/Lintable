# `missing_plural_form`

**Missing plural form** · Localization · default severity: error

A plural variation lacks a form its language needs.

## Rationale

Languages need different plural forms: English uses one and other, Russian one, few, many and other, Arabic all six. When a form is missing, Foundation falls back to `other`, so Russian reads «21 дней» instead of «21 день». The rule checks every plural variation, the source language's too, against the CLDR plural rules for whole numbers up to 1,000. Forms only used for millions, such as French `many`, aren't required. Languages the rule doesn't know are skipped.

## How to fix

Add the missing forms in Xcode's String Catalog editor, which lists the forms each language needs.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Every %lld days" : {
      "localizations" : {
        "ru" : {
          "variations" : {
            ↓"plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "Каждый %lld день" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дня" } }
            }
          }
        }
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
    "Every %lld days" : {
      "localizations" : {
        "fr" : {
          "variations" : {
            "plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jour" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } }
            }
          }
        },
        "ja" : {
          "variations" : {
            "plural" : {
              "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld日ごと" } }
            }
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```
