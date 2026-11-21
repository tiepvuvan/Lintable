// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Binary",
    dependencies: [
        .package(path: "../../../Templates/CustomLinter/AcmeLintPlugins"),
    ],
    targets: [
        .target(
            name: "Failing",
            plugins: [.plugin(name: "AcmeLintBinaryPlugin", package: "AcmeLintPlugins")]
        ),
    ]
)
