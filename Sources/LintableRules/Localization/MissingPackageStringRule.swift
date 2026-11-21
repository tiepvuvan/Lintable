import LintableKit
import SwiftSyntax

public struct MissingPackageStringRule: CatalogRule {
    public struct Host: Codable, Sendable, Equatable {
        public var catalog: String
        public var packages: [String]

        public init(catalog: String, packages: [String]) {
            self.catalog = catalog
            self.packages = packages
        }
    }

    public struct Options: RuleOptions {
        public var hosts: [Host] = []
        public var reportUnusedCopies = true

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public var referencedCatalogPaths: [String] {
        options.hosts.flatMap(\.packages)
    }

    public func check(_ catalog: StringCatalog) -> [Violation] {
        check(catalog, in: CatalogContext(relativePath: catalog.path))
    }

    public func check(_ catalog: StringCatalog, in context: CatalogContext) -> [Violation] {
        let packagePaths = options.hosts.filter { context.isCatalog(atPath: $0.catalog) }.flatMap(\.packages)
        guard !packagePaths.isEmpty else { return [] }
        let start = AbsolutePosition(utf8Offset: 0)
        let entries = Dictionary(catalog.entries.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var violations: [Violation] = []
        var usedByPackages: Set<String> = []
        for path in packagePaths {
            guard let package = context.catalog(atPath: path) else {
                let message = "The config names \(path) as a package catalog for this one, but it isn't a String Catalog Lintable can read."
                violations.append(Violation(position: start, message: message))
                continue
            }
            let live = package.entries.filter { !$0.isStale }.map(\.key)
            usedByPackages.formUnion(live)
            let missing = live.filter { entries[$0] == nil }
            if !missing.isEmpty {
                violations.append(Violation(position: start, message: Self.missingMessage(missing, package: path)))
            }
            for key in live {
                guard let entry = entries[key], entry.isStale else { continue }
                let message = "\(CatalogText.quoted(key)) is stale here, but \(path) still uses it, and this target reads it from this catalog. "
                    + "Set its extraction state to manual."
                violations.append(Violation(position: entry.position, message: message))
            }
        }
        if options.reportUnusedCopies {
            for entry in catalog.entries where entry.extractionState == "manual" && !usedByPackages.contains(entry.key) {
                let message = "\(CatalogText.quoted(entry.key)) is kept by hand for a package, "
                    + "but no package catalog listed for this catalog uses it anymore. Delete it."
                violations.append(Violation(position: entry.position, message: message))
            }
        }
        return violations
    }

    private static func missingMessage(_ keys: [String], package: String) -> String {
        let shown = keys.prefix(10).map(CatalogText.quoted).joined(separator: ", ")
        let rest = keys.count > 10 ? " and \(keys.count - 10) more" : ""
        let count = keys.count == 1 ? "A string" : "\(keys.count) strings"
        let verb = keys.count == 1 ? "is" : "are"
        return "\(count) of \(package) \(verb) missing here: \(shown)\(rest). "
            + "Copy the entries with their comments and translations, and set their extraction state to manual."
    }
}

public extension MissingPackageStringRule {
    static let description = RuleDescription(
        id: "missing_package_string",
        name: "Missing package string",
        summary: "A target's String Catalog lacks a string that a package it links reads from the target's bundle.",
        rationale: """
        App Intents metadata declared in a Swift package is read from the String Catalog of the app or extension that \
        exports it, not from the package's own bundle, and package code that doesn't pass a bundle looks strings up \
        in the main bundle. Xcode only adds strings from a target's own code to its catalog, so these strings are \
        missing and show in English, or Xcode marks the copies stale.
        """,
        category: .localization,
        defaultSeverity: .warning,
        optionDescriptions: [
            "hosts": """
            The catalogs to check, each with `catalog`, its path from the config file, and `packages`, the catalogs of \
            packages whose strings it must hold.
            """,
            "report_unused_copies": "Report manual entries that no listed package catalog uses anymore.",
        ],
        triggeringExamples: [
            Example("""
            1️⃣{
              "sourceLanguage" : "en",
              "strings" : {
                2️⃣"Log Habit" : {
                  "extractionState" : "stale"
                },
                3️⃣"Old Intent Title" : {
                  "extractionState" : "manual"
                }
              },
              "version" : "1.0"
            }
            """, options: """
            hosts:
              - catalog: Example.xcstrings
                packages: [Intents/Localizable.xcstrings]
            """, files: [
                "Intents/Localizable.xcstrings": """
                {
                  "sourceLanguage" : "en",
                  "strings" : {
                    "Log Habit" : { },
                    "Which habit?" : { }
                  },
                  "version" : "1.0"
                }
                """,
            ]),
        ],
        nonTriggeringExamples: [
            Example("""
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
            """, options: """
            hosts:
              - catalog: Example.xcstrings
                packages: [Intents/Localizable.xcstrings]
            """, files: [
                "Intents/Localizable.xcstrings": """
                {
                  "sourceLanguage" : "en",
                  "strings" : {
                    "Log Habit" : { },
                    "Which habit?" : { }
                  },
                  "version" : "1.0"
                }
                """,
            ]),
        ],
        howToFix: """
        Copy each missing entry from the package's catalog, with its comment and translations, and set its \
        `extractionState` to `manual`, so Xcode keeps it although the target's own code doesn't use it. Set a stale \
        copy to `manual` the same way. Delete a manual copy once no package uses it.
        """,
        fileKind: .stringCatalog
    )
}
