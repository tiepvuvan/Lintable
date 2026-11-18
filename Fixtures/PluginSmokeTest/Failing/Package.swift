// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Failing",
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
