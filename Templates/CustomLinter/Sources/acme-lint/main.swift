import AcmeRules
import LintableCommand
import LintableRules

await LintableCommand.main(rulePacks: [BuiltInRules.self, AcmeRules.self])
