// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// MacPotPlayer - A full-featured video player for macOS
// Built with Swift + AVFoundation + FFmpeg + libass

import PackageDescription

let package = Package(
    name: "MacPotPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacPotPlayer", targets: ["MacPotPlayer"])
    ],
    dependencies: [
        // FFmpeg via pre-built XCFramework (see Scripts/setup_dependencies.sh)
        // libass for advanced subtitle rendering
    ],
    targets: [
        .executableTarget(
            name: "MacPotPlayer",
            path: "Sources",
            resources: [
                .process("../Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-import-objc-header", "Bridging/MacPotPlayer-Bridging-Header.h"])
            ]
        ),
        .testTarget(
            name: "MacPotPlayerTests",
            dependencies: ["MacPotPlayer"],
            path: "SourcesTests"
        )
    ]
)
