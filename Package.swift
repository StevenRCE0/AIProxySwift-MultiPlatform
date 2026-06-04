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
    dependencies: [
        // SSE streaming uses the NIO HTTP stack (AsyncHTTPClient) uniformly across
        // platforms — Linux's FoundationNetworking has no async URLSession.bytes.
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(
            name: "AIProxy",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
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
