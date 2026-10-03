// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DobiPet",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DobiPet", targets: ["DobiPet"])],
    targets: [
        .target(name: "DobiCore"),
        .executableTarget(name: "DobiPet", dependencies: ["DobiCore"]),
        .testTarget(name: "DobiCoreTests", dependencies: ["DobiCore"])
    ]
)
