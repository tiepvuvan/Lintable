# `plural_form_without_number`

**Plural form without a number** · Localization · default severity: error

A plural form is used for several numbers but doesn't show the number.

## Rationale

In many languages one plural form covers several numbers. Russian, Ukrainian, Croatian and Serbian use `one` for 1, 21, 31 and 101; French, Portuguese and Hindi use it for 0 and 1. A form written without the number, such as «Каждый день» (every day) for “Every %lld days”, then reads the same for 21 as for 1. The rule reports forms that cover more than one whole number up to 200 and contain no number placeholder. Foundation uses a `zero` form for 0 in every language, so a `zero` form takes 0 away from the others.

## How to fix

Put the number in the form, for example «Каждый %lld день». Where the form only adds 0 to 1, as in French, add a `zero` form instead.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Every %lld days" : {
      "localizations" : {
        "ru" : {
          "variations" : {
            "plural" : {
              "few" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дня" } },
              "many" : { "stringUnit" : { "state" : "translated", "value" : "Каждые %lld дней" } },
              ↓"one" : { "stringUnit" : { "state" : "translated", "value" : "Каждый день" } },
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
        "en" : {
          "variations" : {
            "plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "Every day" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "Every %lld days" } }
            }
          }
        },
        "fr" : {
          "variations" : {
            "plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "Tous les jours" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } },
              "zero" : { "stringUnit" : { "state" : "translated", "value" : "Tous les %lld jours" } }
            }
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```
