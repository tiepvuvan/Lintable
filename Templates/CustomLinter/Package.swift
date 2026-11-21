// swift-tools-version: 6.1
import PackageDescription

let lintable: Package.Dependency = Context.environment["LINTABLE_LOCAL_PATH"].map { .package(path: $0) }
    ?? .package(url: "https://github.com/tiepvuvan/Lintable", from: "0.4.0")

let package = Package(
    name: "AcmeLint",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AcmeRules", targets: ["AcmeRules"]),
        .executable(name: "acme-lint", targets: ["acme-lint"]),
        .plugin(name: "AcmeLintSourcePlugin", targets: ["AcmeLintSourcePlugin"]),
    ],
    dependencies: [
        lintable,
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0"),
    ],
    targets: [
        .target(
            name: "AcmeRules",
            dependencies: [
                .product(name: "LintableKit", package: "Lintable"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "acme-lint",
            dependencies: [
                "AcmeRules",
                .product(name: "LintableCommand", package: "Lintable"),
                .product(name: "LintableRules", package: "Lintable"),
            ]
        ),
        .plugin(
            name: "AcmeLintSourcePlugin",
            capability: .buildTool(),
            dependencies: ["acme-lint"]
        ),
        .testTarget(
            name: "AcmeRulesTests",
            dependencies: [
                "AcmeRules",
                .product(name: "LintableTesting", package: "Lintable"),
            ]
        ),
    ]
)
