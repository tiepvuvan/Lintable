import ArgumentParser
import LintableKit

struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print Lintable's version."
    )

    func run() async throws {
        Console.output(LintableVersion.current)
    }
}
