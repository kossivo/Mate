// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MateCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MateCore",
            targets: ["MateCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MateCore",
            dependencies: [],
            path: "Sources/MateCore"
        ),
        .testTarget(
            name: "MateCoreTests",
            dependencies: ["MateCore"],
            path: "Tests/MateCoreTests"
        )
    ]
)
