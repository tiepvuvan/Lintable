// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LintablePlugins",
    products: [
        .plugin(name: "LintableBuildToolPlugin", targets: ["LintableBuildToolPlugin"]),
        .plugin(name: "LintableCommandPlugin", targets: ["LintableCommandPlugin"]),
    ],
    targets: [
        .binaryTarget(name: "LintableBinary", path: "LintableBinary.artifactbundle"),
        .plugin(
            name: "LintableBuildToolPlugin",
            capability: .buildTool(),
            dependencies: ["LintableBinary"]
        ),
        .plugin(
            name: "LintableCommandPlugin",
            capability: .command(intent: .custom(verb: "lintable", description: "Check Swift files and String Catalogs with Lintable.")),
            dependencies: ["LintableBinary"]
        ),
    ]
)
