// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lantern",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "LanternCore"),
        .executableTarget(name: "Lantern", dependencies: ["LanternCore"]),
        .testTarget(name: "LanternCoreTests", dependencies: ["LanternCore"]),
    ]
)
