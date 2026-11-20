import Foundation
import LintableKit

public enum FileDiscovery {
    public static func resolve(_ path: String, against base: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        var url = base
        for component in expanded.split(separator: "/") where component != "." {
            url = url.appendingPathComponent(String(component))
        }
        return url.standardizedFileURL
    }

    public static func relativePath(of path: String, root: URL) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return standardized.hasPrefix(prefix) ? String(standardized.dropFirst(prefix.count)) : standardized
    }

    public static func isExcluded(_ path: String, configuration: Configuration) -> Bool {
        let relative = relativePath(of: path, root: configuration.rootDirectory)
        return configuration.excluded.contains { Glob($0).matchesPathOrAncestor(relative) }
    }

    public static func filter(_ paths: [String], configuration: Configuration) -> [String] {
        Array(Set(paths
            .filter { FileKind(path: $0) != nil }
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .filter { !isExcluded($0, configuration: configuration) }))
            .sorted()
    }

    public static func files(
        in paths: [String],
        configuration: Configuration,
        currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        fileManager: FileManager = .default
    ) -> [String] {
        let roots: [URL]
        if paths.isEmpty {
            let included = configuration.included.isEmpty ? ["."] : configuration.included
            roots = included.flatMap { expand($0, in: configuration.rootDirectory, fileManager: fileManager) }
        } else {
            roots = paths.map { resolve($0, against: currentDirectory) }
        }
        var found = Set<String>()
        for root in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else { continue }
            if !isDirectory.boolValue {
                found.insert(root.path)
                continue
            }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                let path = url.standardizedFileURL.path
                let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isExcluded(path, configuration: configuration) {
                    if isFolder {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                if !isFolder, FileKind(path: path) != nil {
                    found.insert(path)
                }
            }
        }
        return filter(Array(found), configuration: configuration)
    }

    private static func expand(_ entry: String, in root: URL, fileManager: FileManager) -> [URL] {
        guard entry.contains("*") || entry.contains("?") else {
            return [resolve(entry, against: root)]
        }
        let glob = Glob(entry)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var matches: [URL] = []
        for case let url as URL in enumerator {
            let relative = relativePath(of: url.path, root: root)
            if glob.matches(relative) {
                matches.append(url.standardizedFileURL)
                enumerator.skipDescendants()
            }
        }
        return matches
    }
}
