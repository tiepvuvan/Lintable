// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AcmeLintPlugins",
    products: [
        .plugin(name: "AcmeLintBinaryPlugin", targets: ["AcmeLintBinaryPlugin"]),
    ],
    targets: [
        .binaryTarget(name: "AcmeLintBinary", path: "AcmeLintBinary.artifactbundle"),
        .plugin(
            name: "AcmeLintBinaryPlugin",
            capability: .buildTool(),
            dependencies: ["AcmeLintBinary"]
        ),
    ]
)
