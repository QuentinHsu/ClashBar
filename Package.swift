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
    targets: [
        .target(
            name: "ProxyHelperShared",
            path: "Sources/ProxyHelperShared"),
        .executableTarget(
            name: "CatBar",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/CatBar",
            resources: [
                .process("Resources"),
            ]),
        .executableTarget(
            name: "CatBarProxyHelper",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/ProxyHelper/Daemon"),
    ])
