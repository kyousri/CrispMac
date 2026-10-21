// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CrispMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CrispMac", targets: ["CrispMac"]),
    ],
    targets: [
        .target(name: "CrispCore"),
        .executableTarget(name: "CrispMac", dependencies: ["CrispCore"]),
        .testTarget(name: "CrispCoreTests", dependencies: ["CrispCore"]),
    ]
)
