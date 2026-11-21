# `missing_package_string`

**Missing package string** · Localization · default severity: warning

A target's String Catalog lacks a string that a package it links reads from the target's bundle.

## Rationale

App Intents metadata declared in a Swift package is read from the String Catalog of the app or extension that exports it, not from the package's own bundle, and package code that doesn't pass a bundle looks strings up in the main bundle. Xcode only adds strings from a target's own code to its catalog, so these strings are missing and show in English, or Xcode marks the copies stale.

## Options

| Option | Default | Meaning |
|---|---|---|
| `hosts` | none | The catalogs to check, each with `catalog`, its path from the config file, and `packages`, the catalogs of packages whose strings it must hold. |
| `report_unused_copies` | `true` | Report manual entries that no listed package catalog uses anymore. |

## How to fix

Copy each missing entry from the package's catalog, with its comment and translations, and set its `extractionState` to `manual`, so Xcode keeps it although the target's own code doesn't use it. Set a stale copy to `manual` the same way. Delete a manual copy once no package uses it.

## Reported

With these options:

```yaml
hosts:
  - catalog: Example.xcstrings
    packages: [Intents/Localizable.xcstrings]
```

And `Intents/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Log Habit" : { },
    "Which habit?" : { }
  },
  "version" : "1.0"
}
```

```json
↓{
  "sourceLanguage" : "en",
  "strings" : {
    ↓"Log Habit" : {
      "extractionState" : "stale"
    },
    ↓"Old Intent Title" : {
      "extractionState" : "manual"
    }
  },
  "version" : "1.0"
}
```

## Not reported

With these options:

```yaml
hosts:
  - catalog: Example.xcstrings
    packages: [Intents/Localizable.xcstrings]
```

And `Intents/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Log Habit" : { },
    "Which habit?" : { }
  },
  "version" : "1.0"
}
```

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Log Habit" : {
      "extractionState" : "manual"
    },
    "Which habit?" : {
      "extractionState" : "manual"
    }
  },
  "version" : "1.0"
}
```
