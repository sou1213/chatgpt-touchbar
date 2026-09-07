// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ChatGPTTouchBar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "ChatGPTTouchBarCore", targets: ["ChatGPTTouchBarCore"]),
        .executable(name: "ChatGPTTouchBar", targets: ["ChatGPTTouchBarApp"])
    ],
    targets: [
        .target(name: "ChatGPTTouchBarCore"),
        .executableTarget(
            name: "ChatGPTTouchBarApp",
            dependencies: ["ChatGPTTouchBarCore"]
        ),
        .testTarget(
            name: "ChatGPTTouchBarCoreTests",
            dependencies: ["ChatGPTTouchBarCore"]
        )
    ]
)
