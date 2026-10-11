// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DobiWidgetCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "DobiWidgetCore", targets: ["DobiWidgetCore"])],
    targets: [
        .target(name: "DobiWidgetCore", path: "Shared/Core"),
        .testTarget(name: "DobiWidgetCoreTests", dependencies: ["DobiWidgetCore"], path: "Tests")
    ]
)
