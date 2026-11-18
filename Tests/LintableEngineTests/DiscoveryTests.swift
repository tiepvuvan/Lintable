import Foundation
import LintableEngine
import Testing

@Suite struct GlobTests {
    @Test(arguments: [
        ("**/Tests/**", "Package/Tests/A.swift", true),
        ("**/Tests/**", "Tests/A.swift", true),
        ("**/Tests/**", "Sources/TestsHelper/A.swift", false),
        ("*.swift", "A.swift", true),
        ("*.swift", "Sources/A.swift", false),
        ("Sources/*/A.swift", "Sources/Kit/A.swift", true),
        ("Sources/*/A.swift", "Sources/Kit/Deep/A.swift", false),
        ("**/*.generated.swift", "Sources/Model.generated.swift", true),
        ("Sources/?.swift", "Sources/A.swift", true),
        ("./Sources/", "Sources", true),
    ])
    func patterns(pattern: String, path: String, matches: Bool) {
        #expect(Glob(pattern).matches(path) == matches)
    }

    @Test func excludingAFolderExcludesItsContents() {
        #expect(Glob("Pods").matchesPathOrAncestor("Pods/Alamofire/Source/A.swift"))
        #expect(Glob("**/.build").matchesPathOrAncestor("Package/.build/checkouts/A.swift"))
        #expect(!Glob("Pods").matchesPathOrAncestor("Sources/Pods.swift"))
    }
}

@Suite struct DiscoveryTests {
    @Test func walksIncludedPathsAndSkipsExcludedOnes() throws {
        let directory = try TemporaryDirectory()
        try directory.write("Sources/A.swift", "")
        try directory.write("Sources/B.txt", "")
        try directory.write("Sources/Tests/C.swift", "")
        try directory.write("Other/D.swift", "")
        try directory.write("Sources/.hidden/E.swift", "")
        let config = try configuration("included: [Sources]\nexcluded: ['**/Tests/**']", root: directory.url)
        let files = FileDiscovery.files(in: [], configuration: config)
        #expect(files.map { FileDiscovery.relativePath(of: $0, root: directory.url) } == ["Sources/A.swift"])
    }

    @Test func explicitPathsReplaceIncluded() throws {
        let directory = try TemporaryDirectory()
        try directory.write("Sources/A.swift", "")
        try directory.write("Other/D.swift", "")
        let config = try configuration("included: [Sources]", root: directory.url)
        let files = FileDiscovery.files(in: ["Other"], configuration: config, currentDirectory: directory.url)
        #expect(files.map { FileDiscovery.relativePath(of: $0, root: directory.url) } == ["Other/D.swift"])
    }

    @Test func explicitFileListsStillHonorExcluded() throws {
        let directory = try TemporaryDirectory()
        let config = try configuration("excluded: ['**/Tests/**']", root: directory.url)
        let listed = [
            directory.url.appendingPathComponent("Sources/A.swift").path,
            directory.url.appendingPathComponent("Sources/A.swift").path,
            directory.url.appendingPathComponent("Tests/B.swift").path,
            directory.url.appendingPathComponent("Sources/C.h").path,
        ]
        let files = FileDiscovery.filter(listed, configuration: config)
        #expect(files.map { FileDiscovery.relativePath(of: $0, root: directory.url) } == ["Sources/A.swift"])
    }
}
