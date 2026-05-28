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
  targets: [
    .executableTarget(
      name: "freewind_paste",
      path: "freewind_paste",
      resources: [
        .process("Resources"),
      ],
    ),
  ]
)
