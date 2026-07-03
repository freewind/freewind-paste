// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "freewind_paste",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "freewind_paste",
      targets: ["freewind_paste"]
    ),
  ],
  dependencies: [
    .package(path: "Vendor/freewind-swiftui-debug-bridge")
  ],
  targets: [
    .executableTarget(
      name: "freewind_paste",
      dependencies: [
        .product(
          name: "FreewindSwiftUIDebugBridge",
          package: "freewind-swiftui-debug-bridge"
        ),
      ],
      path: "freewind_paste",
      resources: [
        .process("Resources")
      ]
    )
  ]
)
