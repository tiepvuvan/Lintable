import LintableKit
import Testing

@Test func versionIsSet() {
    #expect(!LintableVersion.current.isEmpty)
}
