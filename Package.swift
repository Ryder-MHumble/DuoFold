// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DuoFold",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LidAngleKit",
            path: "Sources/LidAngleKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "DuoFold",
            dependencies: ["LidAngleKit"],
            path: "Sources/DuoFold",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "lidprobe",
            dependencies: ["LidAngleKit"],
            path: "Sources/lidprobe",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DuoFoldTests",
            dependencies: ["DuoFold"],
            path: "Tests/DuoFoldTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
