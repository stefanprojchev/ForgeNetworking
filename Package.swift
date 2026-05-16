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
        .library(name: "ForgeNetworkingKeychain", targets: ["ForgeNetworkingKeychain"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stefanprojchev/ForgeCore.git", from: "1.0.0"),
        .package(url: "https://github.com/stefanprojchev/ForgeStorage.git", from: "1.0.0"),
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
        .target(
            name: "ForgeNetworkingKeychain",
            dependencies: [
                "ForgeNetworking",
                .product(name: "ForgeCrypt", package: "ForgeStorage"),
            ]
        ),
        .testTarget(
            name: "ForgeNetworkingTests",
            dependencies: [
                "ForgeNetworking",
                "ForgeNetworkingTesting",
                .product(name: "ForgeCore", package: "ForgeCore"),
            ]
        ),
        .testTarget(
            name: "ForgeNetworkingKeychainTests",
            dependencies: [
                "ForgeNetworkingKeychain",
                .product(name: "ForgeCrypt", package: "ForgeStorage"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
