// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Passing",
    dependencies: [
        .package(path: "../../../LintablePlugins"),
    ],
    targets: [
        .target(
            name: "Smoke",
            plugins: [.plugin(name: "LintableBuildToolPlugin", package: "LintablePlugins")]
        ),
    ]
)
