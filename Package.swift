// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Sophon",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macCatalyst(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SophonCore", targets: ["SophonCore"]),
        .library(name: "SophonGemini", targets: ["SophonGemini"]),
        .library(name: "SophonOpenAI", targets: ["SophonOpenAI"]),
        .library(name: "SophonAnthropic", targets: ["SophonAnthropic"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SophonCore",
            dependencies: [],
            path: "Sources/SophonCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "SophonGemini",
            dependencies: [
                "SophonCore",
            ],
            path: "Sources/SophonGemini",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "SophonOpenAI",
            dependencies: [
                "SophonCore",
            ],
            path: "Sources/SophonOpenAI",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "SophonAnthropic",
            dependencies: [
                "SophonCore",
            ],
            path: "Sources/SophonAnthropic",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "SophonTestSupport",
            dependencies: [
                "SophonCore",
            ],
            path: "Tests/SophonTestSupport"
        ),
        .testTarget(
            name: "SophonCoreTests",
            dependencies: ["SophonCore"],
            path: "Tests/SophonCoreTests"
        ),
        .testTarget(
            name: "SophonGeminiTests",
            dependencies: ["SophonGemini", "SophonTestSupport"],
            path: "Tests/SophonGeminiTests"
        ),
        .testTarget(
            name: "SophonOpenAITests",
            dependencies: ["SophonOpenAI", "SophonTestSupport"],
            path: "Tests/SophonOpenAITests"
        ),
        .testTarget(
            name: "SophonAnthropicTests",
            dependencies: ["SophonAnthropic", "SophonTestSupport"],
            path: "Tests/SophonAnthropicTests"
        ),
    ]
)
