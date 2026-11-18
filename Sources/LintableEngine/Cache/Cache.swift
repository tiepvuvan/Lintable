import Foundation
import LintableKit

public struct Cache: Sendable {
    private struct Entry: Codable {
        let key: String
        let violations: [ReportedViolation]
    }

    public let directory: URL
    public let salt: String

    public init(directory: URL, configuration: Configuration, registry: RuleRegistry) {
        self.directory = directory
        salt = [LintableVersion.current, registry.fingerprint, configuration.fingerprint].joined(separator: "|")
    }

    public static var defaultDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("Lintable", isDirectory: true)
    }

    public func load(path: String, source: String) -> [ReportedViolation]? {
        guard let data = FileManager.default.contents(atPath: entryURL(for: path).path),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.key == key(for: source)
        else {
            return nil
        }
        return entry.violations
    }

    public func store(_ violations: [ReportedViolation], path: String, source: String) {
        let entry = Entry(key: key(for: source), violations: violations)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: entryURL(for: path), options: .atomic)
    }

    private func key(for source: String) -> String {
        StableHash.hex(of: salt + "\n" + source)
    }

    private func entryURL(for path: String) -> URL {
        directory.appendingPathComponent(StableHash.hex(of: path) + ".json")
    }
}
