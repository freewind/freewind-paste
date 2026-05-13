// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "PasteBar",
  platforms: [
    .macOS(.v14),
  ],
  dependencies: [
    .package(
      url: "https://github.com/krzysztofzablocki/Inject.git",
      from: "1.2.4"
    ),
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
      dependencies: [
        .product(name: "Inject", package: "Inject"),
      ],
      path: "PasteBar",
      resources: [
        .process("Resources"),
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-interposable"], .when(configuration: .debug)),
      ]
    ),
  ]
)
