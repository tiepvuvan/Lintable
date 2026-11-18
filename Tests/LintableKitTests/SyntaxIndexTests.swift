import LintableKit
import SwiftSyntax
import Testing

@Suite struct ScopeTests {
    @Test func accessorScopeNamesTheProperty() {
        let file = MarkedFile("""
        final class ChartView {
            var highlight: Int = 0 {
                didSet { 1️⃣frame = .zero }
            }
        }
        """)
        let scope = file.index.scope(of: file.token("1️⃣")!)
        #expect(scope.kind == .accessor("didSet"))
        #expect(scope.name == "the `didSet` of `highlight`")
    }

    @Test func closureInsideFunctionListsBothScopes() {
        let file = MarkedFile("""
        func load() {
            run {
                1️⃣value = 1
            }
        }
        """)
        let scopes = file.index.scopes(of: file.token("1️⃣")!)
        #expect(scopes.map(\.kind) == [.closure, .function, .topLevel])
        #expect(scopes[1].name == "`load()`")
    }

    @Test func topLevelCodeHasOnlyTheTopLevelScope() {
        let file = MarkedFile("1️⃣value = 1")
        #expect(file.index.scopes(of: file.token("1️⃣")!).map(\.kind) == [.topLevel])
    }

    @Test func getterOnlyPropertyIsAnAccessor() {
        let file = MarkedFile("""
        struct Box {
            var size: Int { 1️⃣compute() }
        }
        """)
        let scope = file.index.scope(of: file.token("1️⃣")!)
        #expect(scope.kind == .accessor("get"))
        #expect(scope.name == "the `get` of `size`")
    }

    @Test func storedPropertyInitializerIsItsOwnScope() {
        let file = MarkedFile("""
        final class View {
            let label = 1️⃣makeLabel()
        }
        """)
        #expect(file.index.scope(of: file.token("1️⃣")!).kind == .propertyInitializer)
    }

    @Test func localFunctionIsRecognized() {
        let file = MarkedFile("""
        func outer() {
            func inner() {
                1️⃣value = 1
            }
        }
        """)
        let scope = file.index.scope(of: file.token("1️⃣")!)
        #expect(scope.kind == .function)
        #expect(scope.isLocalFunction)
        #expect(file.index.scopes(of: file.token("1️⃣")!)[1].isLocalFunction == false)
    }
}

@Suite struct SignatureTests {
    @Test func displayNameUsesLabelsAndUnderscores() {
        let file = MarkedFile("func 1️⃣fit(_ size: Int, of view: Int) {}")
        let function = file.node(FunctionDeclSyntax.self, at: "1️⃣")!
        #expect(file.index.signature(of: function).displayName == "fit(_:of:)")
    }

    @Test func privateExtensionMakesMembersFilePrivate() {
        let file = MarkedFile("""
        private extension View {
            func 1️⃣layoutBadge() {}
        }
        """)
        let function = file.node(FunctionDeclSyntax.self, at: "1️⃣")!
        #expect(file.index.signature(of: function).accessLevel == .fileprivate)
    }

    @Test func membersOfAPrivateTypeAreAtMostFilePrivate() {
        let file = MarkedFile("""
        private final class Badge {
            func 1️⃣layoutDot() {}
            public func 2️⃣reset() {}
        }
        """)
        #expect(file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!).accessLevel == .fileprivate)
        #expect(file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "2️⃣")!).accessLevel == .fileprivate)
    }

    @Test func overrideStaticAndAttributesAreSeen() {
        let file = MarkedFile("""
        final class View: UIView {
            @objc override func 1️⃣layoutSubviews() {}
            @MainActor static func 2️⃣make() {}
        }
        """)
        let layout = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!)
        let make = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "2️⃣")!)
        #expect(layout.isOverride)
        #expect(layout.isObjC)
        #expect(make.isStatic)
        #expect(make.hasAttribute("MainActor"))
        #expect(layout.accessLevel == .internal)
    }

    @Test func initializerSignature() {
        let file = MarkedFile("""
        final class View {
            1️⃣init(frame: Int, _ style: Int = 0) {}
        }
        """)
        let initializer = file.node(InitializerDeclSyntax.self, at: "1️⃣")!
        let signature = file.index.signature(of: initializer)
        #expect(signature.displayName == "init(frame:_:)")
        #expect(signature.parameters.map(\.hasDefaultValue) == [false, true])
    }
}

@Suite struct TypeTests {
    @Test func enclosingTypesInnermostFirst() {
        let file = MarkedFile("""
        enum Outer {
            struct Inner {
                func 1️⃣run() {}
            }
        }
        extension Outer.Inner {
            func 2️⃣stop() {}
        }
        """)
        #expect(file.index.types(of: file.token("1️⃣")!).map(\.name) == ["Inner", "Outer"])
        let extensionType = file.index.types(of: file.token("2️⃣")!)[0]
        #expect(extensionType.kind == .extension)
        #expect(extensionType.name == "Inner")
    }

    @Test func inheritanceThroughASameFileSuperclass() {
        let file = MarkedFile("""
        class BaseLayout: UICollectionViewLayout, Sendable {}
        final class GridLayout: BaseLayout {
            func 1️⃣prepareGrid() {}
        }
        extension GridLayout {
            func 2️⃣pin() {}
        }
        final class Other: NSObject {
            func 3️⃣run() {}
        }
        """)
        let exempt: Set<String> = ["UICollectionViewLayout"]
        #expect(file.index.inheritsFrom(file.index.types(of: file.token("1️⃣")!)[0], anyOf: exempt))
        #expect(file.index.inheritsFrom(file.index.types(of: file.token("2️⃣")!)[0], anyOf: exempt))
        #expect(!file.index.inheritsFrom(file.index.types(of: file.token("3️⃣")!)[0], anyOf: exempt))
    }
}

@Suite struct CallTests {
    @Test func callsMatchByNameLabelsAndDefaults() {
        let file = MarkedFile("""
        final class View {
            private func 1️⃣layoutBadge(animated: Bool = false) {}
            func run() {
                layoutBadge()
                self.layoutBadge(animated: true)
                other.layoutBadge()
                layoutBadge(fast: true)
            }
        }
        """)
        let signature = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!)
        let calls = file.index.calls(to: signature)
        #expect(calls.count == 3)
        #expect(calls.map(\.receiver) == [.implicit, .explicitSelf, .other("other")])
    }

    @Test func trailingClosureFillsTheLastParameter() {
        let file = MarkedFile("""
        func 1️⃣perform(delay: Int = 0, work: () -> Void) {}
        func run() {
            perform { }
            perform(delay: 1) { }
            perform(work: {})
        }
        """)
        let signature = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!)
        #expect(file.index.calls(to: signature).count == 3)
    }

    @Test func variadicArguments() {
        let file = MarkedFile("""
        func 1️⃣sum(_ values: Int...) {}
        func run() {
            sum(1, 2, 3)
        }
        """)
        let signature = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!)
        #expect(file.index.calls(to: signature).count == 1)
    }
}

@Suite struct ReferenceTests {
    @Test func selectorsAndValuesAreReferences() {
        let file = MarkedFile("""
        final class View {
            @objc private func 1️⃣handle(_ recognizer: Int) {}
            private func 2️⃣refresh() {}
            func setUp() {
                add(#selector(handle(_:)))
                add(#selector(Self.refresh))
                schedule(refresh)
                refresh()
            }
        }
        """)
        let handle = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "1️⃣")!)
        let refresh = file.index.signature(of: file.node(FunctionDeclSyntax.self, at: "2️⃣")!)
        #expect(file.index.references(to: handle).map(\.kind) == [.selector])
        #expect(file.index.references(to: refresh).map(\.kind) == [.selector, .value])
    }
}

@Suite struct ClosureInvocationTests {
    @Test func namesTheCallAClosureIsPassedTo() {
        let file = MarkedFile("""
        func run() {
            DispatchQueue.main.async 1️⃣{ }
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: 2️⃣{ })
            Task 3️⃣{ }
            DispatchQueue.global().async 4️⃣{ }
            UIView.animate(withDuration: 1, animations: 5️⃣{ }, completion: 6️⃣{ _ in })
        }
        """)
        func callee(_ marker: String) -> ClosureInvocation? {
            file.node(ClosureExprSyntax.self, at: marker).flatMap { file.index.invocation(of: $0) }
        }
        #expect(callee("1️⃣")?.calleeName == "DispatchQueue.main.async")
        #expect(callee("2️⃣")?.calleeName == "DispatchQueue.main.asyncAfter")
        #expect(callee("3️⃣")?.calleeName == "Task")
        #expect(callee("4️⃣")?.calleeName == "DispatchQueue.global.async")
        #expect(callee("5️⃣")?.calleeName == "UIView.animate")
        #expect(callee("6️⃣")?.calleeName == "UIView.animate")
    }

    @Test func patternsAnchorTheFirstAndLastComponents() throws {
        let file = MarkedFile("""
        func run() {
            DispatchQueue.main.async 1️⃣{ }
            publisher.sink 2️⃣{ _ in }
        }
        """)
        let async = try #require(file.node(ClosureExprSyntax.self, at: "1️⃣").flatMap { file.index.invocation(of: $0) })
        let sink = try #require(file.node(ClosureExprSyntax.self, at: "2️⃣").flatMap { file.index.invocation(of: $0) })
        #expect(async.matches("DispatchQueue.async"))
        #expect(async.matches("DispatchQueue.main.async"))
        #expect(!async.matches("DispatchQueue.global.async"))
        #expect(!async.matches("async.DispatchQueue"))
        #expect(sink.matches("sink"))
        #expect(!sink.matches("DispatchQueue.sink"))
    }
}

@Suite struct AssignmentTests {
    @Test func targetsAndOperators() {
        let file = MarkedFile("""
        func run() {
            1️⃣frame = .zero
            2️⃣self.view.frame.origin.x += 8
            3️⃣badge?.center = point
            4️⃣(a, b) = (1, 2)
            5️⃣items[0].frame = .zero
            6️⃣total == 1
        }
        """)
        func target(_ marker: String) -> AssignmentTarget? {
            file.node(InfixOperatorExprSyntax.self, at: marker).flatMap { file.index.assignmentTarget(of: $0) }
        }
        #expect(target("1️⃣")?.root == .name("frame"))
        #expect(target("1️⃣")?.path == ["frame"])
        #expect(target("2️⃣")?.root == .explicitSelf)
        #expect(target("2️⃣")?.path == ["view", "frame", "origin", "x"])
        #expect(target("2️⃣")?.operatorText == "+=")
        #expect(target("3️⃣")?.path == ["badge", "center"])
        #expect(target("4️⃣") == nil)
        #expect(target("5️⃣")?.root == .other)
        #expect(target("5️⃣")?.path == ["frame"])
        #expect(target("6️⃣") == nil)
    }
}

@Suite struct LocalVariableTests {
    @Test func shadowingDeclarationsAreLocals() {
        let file = MarkedFile("""
        func run(frame: Int, size: Int) {
            var bounds = view.bounds
            1️⃣bounds.origin.y = 8
            guard let center = point else { return }
            2️⃣center.x = 1
            if let origin = start {
                3️⃣origin.x = 1
            }
            4️⃣origin.x = 2
            items.forEach { position in
                5️⃣position.x = 1
            }
            6️⃣frame = 1
            7️⃣anchor = 1
        }
        """)
        #expect(file.index.isLocalVariable(named: "bounds", at: file.token("1️⃣")!))
        #expect(file.index.isLocalVariable(named: "center", at: file.token("2️⃣")!))
        #expect(file.index.isLocalVariable(named: "origin", at: file.token("3️⃣")!))
        #expect(!file.index.isLocalVariable(named: "origin", at: file.token("4️⃣")!))
        #expect(file.index.isLocalVariable(named: "position", at: file.token("5️⃣")!))
        #expect(file.index.isLocalVariable(named: "frame", at: file.token("6️⃣")!))
        #expect(!file.index.isLocalVariable(named: "anchor", at: file.token("7️⃣")!))
    }

    @Test func typePropertiesAreNotLocals() {
        let file = MarkedFile("""
        final class View {
            var frame = 0
            func run() {
                1️⃣frame = 1
            }
        }
        """)
        #expect(!file.index.isLocalVariable(named: "frame", at: file.token("1️⃣")!))
    }

    @Test func accessorImplicitParameters() {
        let file = MarkedFile("""
        var value = 0 {
            didSet { 1️⃣oldValue.reset() }
        }
        """)
        #expect(file.index.isLocalVariable(named: "oldValue", at: file.token("1️⃣")!))
    }
}

@Suite struct LintFileTests {
    @Test func locationsAndLines() {
        let file = LintFile(path: "A.swift", source: "let a = 1\n  let bé = 2\n")
        #expect(file.location(of: AbsolutePosition(utf8Offset: 0)) == LineColumn(line: 1, column: 1))
        #expect(file.location(of: AbsolutePosition(utf8Offset: 12)) == LineColumn(line: 2, column: 3))
        #expect(file.lineText(2) == "let bé = 2")
        #expect(file.lineText(9).isEmpty)
        #expect(!file.hasSyntaxErrors)
    }

    @Test func examplesStripMarkers() {
        let parsed = Example("a1️⃣bé2️⃣c").parse()
        #expect(parsed.source == "abéc")
        #expect(parsed.markers == [Marker(name: "1️⃣", utf8Offset: 1), Marker(name: "2️⃣", utf8Offset: 4)])
    }

    @Test func ruleIDsAreSnakeCase() {
        #expect(RuleID("layout_lifecycle").isWellFormed)
        #expect(RuleID("rule2").isWellFormed)
        #expect(!RuleID("LayoutLifecycle").isWellFormed)
        #expect(!RuleID("layout__lifecycle").isWellFormed)
        #expect(!RuleID("_layout").isWellFormed)
    }
}
