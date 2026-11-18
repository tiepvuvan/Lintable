import ArgumentParser
import LintableKit

public enum LintableCommand {
    public static func main(rulePacks: [any RulePack.Type]) async {
        LoadedRulePacks.packs = rulePacks
        await RootCommand.main()
    }
}

enum LoadedRulePacks {
    nonisolated(unsafe) static var packs: [any RulePack.Type] = []
}

struct RootCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lintable",
        abstract: "Architecture rules for Swift, next to SwiftLint.",
        version: LintableVersion.current,
        subcommands: [
            LintCommand.self,
            BaselineCommand.self,
            RulesCommand.self,
            InitCommand.self,
            VersionCommand.self,
        ],
        defaultSubcommand: LintCommand.self
    )
}
