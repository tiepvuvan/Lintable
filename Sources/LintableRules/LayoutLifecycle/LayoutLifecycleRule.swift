import LintableKit

public struct LayoutLifecycleRule: Rule {
    public let options: LayoutLifecycleOptions

    public init(options: LayoutLifecycleOptions) {
        self.options = options
    }

    public func check(_ file: LintFile) -> [Violation] {
        LayoutLifecycleAnalysis(file: file, options: options).violations()
    }
}
