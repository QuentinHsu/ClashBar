// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CatBar",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "CatBar", targets: ["CatBar"]),
        .executable(name: "CatBarProxyHelper", targets: ["CatBarProxyHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.1"),
    ],
    targets: [
        .target(
            name: "ProxyHelperShared",
            path: "Sources/ProxyHelperShared"),
        .executableTarget(
            name: "CatBar",
            dependencies: [
                "ProxyHelperShared",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/CatBar",
            resources: [
                .process("Resources"),
            ]),
        .executableTarget(
            name: "CatBarProxyHelper",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/ProxyHelper/Daemon"),
        .testTarget(
            name: "CatBarTests",
            dependencies: ["CatBar"],
            path: "Tests/CatBarTests"),
    ])
