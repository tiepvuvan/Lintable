import LintableKit

public struct DirectiveProcessor: Sendable {
    public let configuration: Configuration
    public let knownRuleIDs: Set<RuleID>

    public init(configuration: Configuration, knownRuleIDs: Set<RuleID>) {
        self.configuration = configuration
        self.knownRuleIDs = knownRuleIDs
    }

    public func apply(_ violations: [ReportedViolation], in file: LintFile, relativePath: String) -> [ReportedViolation] {
        let parsed = DirectiveParser.parse(file)
        let factory = EngineViolationFactory(configuration: configuration, file: file, relativePath: relativePath)
        let suppressions = Suppressions(parsed, lineCount: file.lineCount)
        var usedDirectives = Set<Int>()
        let kept = violations.filter { violation in
            guard let directives = suppressions.directives(suppressing: violation) else { return true }
            usedDirectives.formUnion(directives)
            return false
        }
        let enabled = configuration.enabledRuleIDs
        var engineViolations = parsed.invalid.map(factory.invalid)
        for (index, directive) in parsed.directives.enumerated() {
            engineViolations += validate(directive, factory: factory)
            let isSuperfluous = directive.kind != .enable
                && !usedDirectives.contains(index)
                && directive.ruleIDs.contains(where: enabled.contains)
            if isSuperfluous {
                engineViolations.append(factory.superfluous(directive))
            }
        }
        return kept + engineViolations
    }

    private func validate(_ directive: Directive, factory: EngineViolationFactory) -> [ReportedViolation] {
        var violations = directive.ruleIDs
            .filter { !knownRuleIDs.contains($0) && !EngineRules.ids.contains($0) }
            .map { factory.unknownRule($0, in: directive) }
        if configuration.requireReasons, directive.kind != .enable, directive.reason == nil {
            violations.append(factory.missingReason(directive))
        }
        return violations
    }
}

private struct Suppressions {
    private var directivesByLine: [Int: [RuleID: [Int]]] = [:]

    init(_ parsed: ParsedDirectives, lineCount: Int) {
        var openRegions: [RuleID: (index: Int, line: Int)] = [:]
        for (index, directive) in parsed.directives.enumerated() {
            switch directive.kind {
            case .disableNext:
                let target = parsed.codeLines.first { $0 > directive.line } ?? directive.line + 1
                directive.ruleIDs.forEach { suppress($0, from: target, through: target, by: index) }
            case .disableThis:
                directive.ruleIDs.forEach { suppress($0, from: directive.line, through: directive.line, by: index) }
            case .disable:
                for id in directive.ruleIDs where openRegions[id] == nil {
                    openRegions[id] = (index, directive.line)
                }
            case .enable:
                for id in directive.ruleIDs {
                    if let open = openRegions.removeValue(forKey: id) {
                        suppress(id, from: open.line + 1, through: directive.line - 1, by: open.index)
                    }
                }
            }
        }
        for (id, open) in openRegions {
            suppress(id, from: open.line + 1, through: lineCount, by: open.index)
        }
    }

    func directives(suppressing violation: ReportedViolation) -> [Int]? {
        directivesByLine[violation.line]?[violation.ruleID]
    }

    private mutating func suppress(_ id: RuleID, from first: Int, through last: Int, by directive: Int) {
        guard first <= last else { return }
        for line in first ... last {
            directivesByLine[line, default: [:]][id, default: []].append(directive)
        }
    }
}

private struct EngineViolationFactory {
    let configuration: Configuration
    let file: LintFile
    let relativePath: String

    func unknownRule(_ id: RuleID, in directive: Directive) -> ReportedViolation {
        make(EngineRules.unknownRule, "`\(id)` isn't a loaded rule, so this directive suppresses nothing.", directive.line, directive.column)
    }

    func missingReason(_ directive: Directive) -> ReportedViolation {
        let ids = directive.ruleIDs.map(\.rawValue).joined(separator: ", ")
        let message = "Add a reason: `// lintable:\(directive.kind.rawValue) \(ids) - <why the rule doesn't apply>`."
        return make(EngineRules.missingReason, message, directive.line, directive.column)
    }

    func superfluous(_ directive: Directive) -> ReportedViolation {
        make(EngineRules.superfluousDirective, "This directive suppresses no violation. Remove it.", directive.line, directive.column)
    }

    func invalid(_ directive: InvalidDirective) -> ReportedViolation {
        let message = "`\(directive.text)` isn't a valid directive. "
            + "Use `// lintable:disable:next <rule> - <reason>`, `disable:this`, `disable` or `enable`."
        return make(EngineRules.invalidDirective, message, directive.line, directive.column)
    }

    private func make(_ id: RuleID, _ message: String, _ line: Int, _ column: Int) -> ReportedViolation {
        ReportedViolation(
            ruleID: id,
            severity: configuration.severity(ofEngineRule: id),
            message: message,
            path: file.path,
            relativePath: relativePath,
            line: line,
            column: column,
            lineText: file.lineText(line)
        )
    }
}
