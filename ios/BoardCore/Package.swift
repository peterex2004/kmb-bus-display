// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BoardCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BoardCore",
            targets: ["BoardCore"]
        )
    ],
    targets: [
        .target(name: "BoardCore"),
        .testTarget(
            name: "BoardCoreTests",
            dependencies: ["BoardCore"]
        )
    ]
)
