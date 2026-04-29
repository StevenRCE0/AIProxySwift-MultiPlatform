// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIProxyMultiPlatform",
    platforms: [
         .iOS(.v15),
         .macOS(.v13),
         .visionOS(.v1),
         .watchOS(.v9)
    ],
    products: [
        .library(
            name: "AIProxy",
            targets: ["AIProxy"]),
        // Optional: opt in to OpenAI Realtime + audio capture/playback.
        // Requires AVFoundation; not part of the core AIProxy target.
        .library(
            name: "AIProxyRealtime",
            targets: ["AIProxyRealtime"]),
    ],
    targets: [
        .target(
            name: "AIProxy",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(nil),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .target(
            name: "AIProxyRealtime",
            dependencies: ["AIProxy"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(nil),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "AIProxyTests",
            dependencies: ["AIProxy"]
        ),
        .testTarget(
            name: "AIProxyRealtimeTests",
            dependencies: ["AIProxyRealtime"]
        ),
    ]
)
