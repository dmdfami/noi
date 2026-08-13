// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChatGPTAudioV2",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ChatGPTAudioV2", targets: ["ChatGPTAudioV2"]),
    ],
    targets: [
        .executableTarget(
            name: "ChatGPTAudioV2",
            path: "Sources"
        ),
    ]
)
