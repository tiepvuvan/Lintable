import LintableKit
import SwiftSyntax

public struct UnlabeledImageButtonRule: Rule {
    public struct Options: RuleOptions {
        public var swiftuiControls = ["Button", "Link", "Menu", "NavigationLink"]
        public var labelModifiers = ["accessibilityLabel", "accessibilityRepresentation"]
        public var labelProperties = ["accessibilityLabel", "accessibilityAttributedLabel", "title"]

        public init() {}
    }

    public let options: Options

    public init(options: Options) {
        self.options = options
    }

    public func check(_ file: LintFile) -> [Violation] {
        let swiftUI = SwiftUIImageButtons(options: options, index: file.index)
        swiftUI.run(on: file.tree)
        let uiKit = UIKitImageButtons(options: options, index: file.index)
        uiKit.walk(file.tree)
        return (swiftUI.violations + uiKit.findViolations()).sorted { $0.position < $1.position }
    }
}
