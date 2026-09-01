// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "RealSizePreviewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RealSizePreviewer", targets: ["RealSizePreviewer"])
    ],
    targets: [
        .executableTarget(
            name: "RealSizePreviewer",
            path: "Sources/RealSizePreviewer"
        ),
        .testTarget(
            name: "RealSizePreviewerTests",
            dependencies: ["RealSizePreviewer"],
            path: "Tests/RealSizePreviewerTests"
        )
    ]
)
