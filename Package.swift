// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Frank",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "FrankCore"),
        .executableTarget(name: "Frank", dependencies: ["FrankCore"]),
        .testTarget(name: "FrankCoreTests", dependencies: ["FrankCore"]),
    ]
)
