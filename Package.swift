// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lintable",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LintableKit", targets: ["LintableKit"]),
        .library(name: "LintableEngine", targets: ["LintableEngine"]),
        .library(name: "LintableCommand", targets: ["LintableCommand"]),
        .library(name: "LintableRules", targets: ["LintableRules"]),
        .library(name: "LintableTesting", targets: ["LintableTesting"]),
        .executable(name: "lintable", targets: ["lintable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
    ],
    targets: [
        .target(
            name: "LintableKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "LintableEngine",
            dependencies: [
                "LintableKit",
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(
            name: "LintableCommand",
            dependencies: [
                "LintableEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "LintableRules",
            dependencies: ["LintableKit"]
        ),
        .target(
            name: "LintableTesting",
            dependencies: ["LintableKit", "LintableEngine"]
        ),
        .executableTarget(
            name: "lintable",
            dependencies: ["LintableCommand", "LintableRules"]
        ),
        .testTarget(
            name: "LintableKitTests",
            dependencies: ["LintableKit"]
        ),
        .testTarget(
            name: "LintableEngineTests",
            dependencies: [
                "LintableEngine",
                "LintableCommand",
                "LintableTesting",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "LintableTestingTests",
            dependencies: ["LintableTesting"]
        ),
        .testTarget(
            name: "LintableRulesTests",
            dependencies: ["LintableRules", "LintableTesting"]
        ),
    ]
)
