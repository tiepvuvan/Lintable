// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReleaseGate",
    dependencies: [
        .package(path: "../../../LintablePlugins"),
    ],
    targets: [
        .target(
            name: "Smoke",
            resources: [.copy("Localizable.xcstrings")],
            plugins: [.plugin(name: "LintableBuildToolPlugin", package: "LintablePlugins")]
        ),
    ]
)
