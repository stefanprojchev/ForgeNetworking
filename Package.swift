// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ForgeNetworking",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ForgeNetworking", targets: ["ForgeNetworking"]),
        .library(name: "ForgeNetworkingTesting", targets: ["ForgeNetworkingTesting"]),
    ],
    dependencies: [
        .package(path: "../ForgeCore"),
    ],
    targets: [
        .target(
            name: "ForgeNetworking",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
            ]
        ),
        .target(
            name: "ForgeNetworkingTesting",
            dependencies: ["ForgeNetworking"]
        ),
        .testTarget(
            name: "ForgeNetworkingTests",
            dependencies: [
                "ForgeNetworking",
                "ForgeNetworkingTesting",
                .product(name: "ForgeCore", package: "ForgeCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
