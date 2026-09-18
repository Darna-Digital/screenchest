// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenSail",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ScreenSail",
            path: "Sources/ScreenSail",
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
            name: "ScreenSailTests",
            dependencies: ["ScreenSail"],
            path: "Tests/ScreenSailTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
