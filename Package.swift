// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "freewind_paste",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(
      name: "freewind_paste",
      targets: ["freewind_paste"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/freewind/freewind-swiftui-debug-bridge.git",
      revision: "90b79324194d59793c8f49308789d2a799406db5"
    ),
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
        .process("Resources"),
      ],
    ),
  ]
)
