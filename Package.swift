// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenChest",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ScreenChest",
            path: "Sources/ScreenChest",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Metal"),
            ]
        ),
        .testTarget(
            name: "ScreenChestTests",
            dependencies: ["ScreenChest"],
            path: "Tests/ScreenChestTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
