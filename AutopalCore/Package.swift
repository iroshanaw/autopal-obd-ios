// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutopalCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AutopalCore",
            targets: ["AutopalCore"]
        )
    ],
    targets: [
        .target(
            name: "AutopalCore",
            dependencies: [],
            path: "Sources/AutopalCore"
        ),
        .testTarget(
            name: "AutopalCoreTests",
            dependencies: ["AutopalCore"],
            path: "Tests/AutopalCoreTests",
            resources: [
                .copy("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
