// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServerMicrosoftAccount",
    products: [
        .library(
            name: "ServerMicrosoftAccount",
            targets: ["ServerMicrosoftAccount"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SyncServerII/ServerAccount.git", from: "0.0.2"),
    ],
    targets: [
        .target(
            name: "ServerMicrosoftAccount",
            dependencies: ["ServerAccount"]),
        .testTarget(
            name: "ServerMicrosoftAccountTests",
            dependencies: ["ServerMicrosoftAccount"]),
    ]
)
