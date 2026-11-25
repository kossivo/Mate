// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MateCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MateCore",
            targets: ["MateCore"]
        ),
        .executable(
            name: "MateApp",
            targets: ["MateApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MateCore",
            dependencies: [],
            path: "Sources/MateCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "MateApp",
            dependencies: ["MateCore"],
            path: "Sources/MateApp"
        ),
        .testTarget(
            name: "MateCoreTests",
            dependencies: ["MateCore"],
            path: "Tests/MateCoreTests"
        )
    ]
)
