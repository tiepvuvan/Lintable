// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Source",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../../Templates/CustomLinter"),
    ],
    targets: [
        .target(
            name: "Passing",
            plugins: [.plugin(name: "AcmeLintSourcePlugin", package: "CustomLinter")]
        ),
        .target(
            name: "Failing",
            plugins: [.plugin(name: "AcmeLintSourcePlugin", package: "CustomLinter")]
        ),
    ]
)
