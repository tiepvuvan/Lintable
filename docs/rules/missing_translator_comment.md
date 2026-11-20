# `missing_translator_comment`

**Missing translator comment** · Localization · default severity: warning

A String Catalog key has no comment for translators.

## Rationale

Translators see a key without the screen around it. "Done" can be a button or a status, "Log" a verb or a noun, and a comment is the only place that says which. The rule reports keys with no comment, skipping keys marked Don't Translate, stale keys and empty keys.

## How to fix

Pass `comment:` where the code creates the string, or add the comment in Xcode's String Catalog editor.

## Reported

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"Done" : {
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
      "comment" : "Button that closes the reminder editor."
    },
    "Habitify" : {
      "shouldTranslate" : false
    }
  },
  "version" : "1.0"
}
```
