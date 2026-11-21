import Foundation
import PackagePlugin

@main
struct AcmeLintSourcePlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        return try LintCommands.make(
            tool: context.tool(named: "acme-lint").url,
            target: LintTarget(
                name: target.name,
                files: target.sourceFiles.map(\.url).filter(LintCommands.isLinted),
                searchFrom: target.directoryURL,
                root: context.package.directoryURL
            ),
            workDirectory: context.pluginWorkDirectoryURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension AcmeLintSourcePlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            try LintCommands.make(
                tool: context.tool(named: "acme-lint").url,
                target: LintTarget(
                    name: target.displayName,
                    files: target.inputFiles.map(\.url).filter(LintCommands.isLinted),
                    searchFrom: context.xcodeProject.directoryURL,
                    root: context.xcodeProject.directoryURL
                ),
                workDirectory: context.pluginWorkDirectoryURL
            )
        }
    }
#endif

struct LintTarget {
    let name: String
    let files: [URL]
    let searchFrom: URL
    let root: URL
}

enum LintCommands {
    static func isLinted(_ file: URL) -> Bool {
        ["swift", "xcstrings"].contains(file.pathExtension)
    }

    static func make(tool: URL, target: LintTarget, workDirectory: URL) throws -> [Command] {
        guard !target.files.isEmpty, let configuration = nearestConfiguration(from: target.searchFrom, root: target.root) else {
            return []
        }
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let fileList = workDirectory.appendingPathComponent("files.txt")
        try writeIfChanged(Data(target.files.map(\.path).sorted().joined(separator: "\n").utf8), to: fileList)
        let releaseGate = workDirectory.appendingPathComponent("AcmeLintReleaseGate.swift")
        return [
            .buildCommand(
                displayName: "Acme lint \(target.name)",
                executable: tool,
                arguments: [
                    "lint",
                    "--config", configuration.path,
                    "--reporter", "xcode",
                    "--files-from", fileList.path,
                    "--cache-path", workDirectory.appendingPathComponent("Cache").path,
                    "--release-gate", releaseGate.path,
                ],
                inputFiles: target.files + [configuration],
                outputFiles: [releaseGate]
            ),
        ]
    }

    static func writeIfChanged(_ data: Data, to url: URL) throws {
        guard FileManager.default.contents(atPath: url.path) != data else { return }
        try data.write(to: url)
    }

    static func nearestConfiguration(from start: URL, root: URL) -> URL? {
        let rootPath = root.standardizedFileURL.path
        var current = start.standardizedFileURL
        while true {
            let candidate = current.appendingPathComponent(".lintable.yml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = current.deletingLastPathComponent()
            if current.path == rootPath || parent.path == current.path {
                return nil
            }
            current = parent
        }
    }
}
