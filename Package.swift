// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BF",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)
    ],
    products: [
        .library(name: "BF", targets: ["BF"]),
        .executable(name: "bf", targets: ["BFRun"]),
    ],
    targets: [
        .target(name: "BF"),
        .executableTarget(name: "BFRun", dependencies: ["BF"]),
        .testTarget(name: "BFTests", dependencies: ["BF"]),
    ]
)
