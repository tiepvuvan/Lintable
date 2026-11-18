import ArgumentParser
import Foundation
import LintableEngine

struct ConfigOptions: ParsableArguments {
    @Option(name: .long, help: "The config file. Defaults to the nearest .lintable.yml, searching up from the current directory.")
    var config: String?

    func registry() throws -> RuleRegistry {
        do {
            return try RuleRegistry(packs: LoadedRulePacks.packs)
        } catch {
            Console.error(String(describing: error))
            throw ExitCode(3)
        }
    }

    func configurationURL() -> URL? {
        if let config {
            return URL(fileURLWithPath: config)
        }
        return Configuration.find(startingAt: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    }

    func load(registry: RuleRegistry) throws -> Configuration {
        guard let url = configurationURL() else {
            Console.error(ConfigurationError.notFound(searchedFrom: FileManager.default.currentDirectoryPath).description)
            throw ExitCode(2)
        }
        do {
            return try Configuration.load(from: url, registry: registry)
        } catch let error as ConfigurationError {
            Console.error("\(url.path): \(error.description)")
            throw ExitCode(2)
        }
    }
}

struct SelectionOptions: ParsableArguments {
    @Argument(help: "Files or folders to check. Defaults to the config's `included` paths.")
    var paths: [String] = []

    @Option(name: .customLong("files-from"), help: "A file listing the Swift files to check, one path per line.")
    var filesFrom: String?

    func files(configuration: Configuration) throws -> [String] {
        guard let filesFrom else {
            return FileDiscovery.files(in: paths, configuration: configuration)
        }
        guard let data = FileManager.default.contents(atPath: filesFrom) else {
            Console.error("Can't read the file list at \(filesFrom).")
            throw ExitCode(2)
        }
        let listed = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
        return FileDiscovery.filter(listed, configuration: configuration)
    }
}

struct CacheOptions: ParsableArguments {
    @Option(name: .customLong("cache-path"), help: "Where to keep results between runs.")
    var cachePath: String?

    @Flag(name: .customLong("no-cache"), help: "Check every file, ignoring and not writing the cache.")
    var noCache = false

    func cache(configuration: Configuration, registry: RuleRegistry) -> Cache? {
        guard !noCache else { return nil }
        let directory = cachePath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Cache.defaultDirectory
        return Cache(directory: directory, configuration: configuration, registry: registry)
    }
}
