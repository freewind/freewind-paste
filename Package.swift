// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "PasteBar",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(
      name: "PasteBar",
      targets: ["PasteBar"]
    ),
  ],
  targets: [
    .executableTarget(
      name: "PasteBar",
      path: "PasteBar",
      resources: [
        .process("Resources"),
      ]
    ),
  ]
)
