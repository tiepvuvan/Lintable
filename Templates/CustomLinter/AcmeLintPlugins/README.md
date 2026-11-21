# AcmeLintPlugins

The build-tool plugin for AcmeLint, with a prebuilt `acme-lint` binary, so adding the
plugin downloads one zip and never compiles swift-syntax.

```swift
dependencies: [
    .package(url: "https://example.com/acme/AcmeLintPlugins", from: "1.0.0"),
],
targets: [
    .target(
        name: "App",
        plugins: [.plugin(name: "AcmeLintBinaryPlugin", package: "AcmeLintPlugins")]
    ),
]
```

In an Xcode project, add the package, then add `AcmeLintBinaryPlugin` under each
target's Build Phases → Run Build Tool Plug-ins.

The plugin looks for the nearest `.lintable.yml`, from the target's folder up to the
package or project root, and does nothing without one. It checks the target's Swift
files and String Catalogs with Lintable's rules and Acme's.
