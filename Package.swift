// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyWipe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "KeyWipe", targets: ["KeyWipe"])],
    targets: [
        .target(name: "KeyWipeCore"),
        .executableTarget(name: "KeyWipe", dependencies: ["KeyWipeCore"]),
        .testTarget(name: "KeyWipeCoreTests", dependencies: ["KeyWipeCore"]),
    ]
)
