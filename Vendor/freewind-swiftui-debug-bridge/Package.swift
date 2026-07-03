// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FreewindSwiftUIDebugBridge",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FreewindSwiftUIDebugBridge",
            targets: ["FreewindSwiftUIDebugBridge"]
        ),
    ],
    targets: [
        .target(
            name: "FreewindSwiftUIDebugBridge"
        ),
    ]
)
