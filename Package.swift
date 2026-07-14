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
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SophonCore",
            dependencies: [],
            path: "Sources/SophonCore"
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
        .testTarget(
            name: "SophonCoreTests",
            dependencies: ["SophonCore"],
            path: "Tests/SophonCoreTests"
        ),
        .testTarget(
            name: "SophonGeminiTests",
            dependencies: ["SophonGemini"],
            path: "Tests/SophonGeminiTests"
        ),
    ]
)
