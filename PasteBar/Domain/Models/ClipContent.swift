import Foundation

struct ClipContent: Codable, Equatable, Hashable {
  var text: String?
  var imageAssetPath: String?
  var filePaths: [String]?

  static func text(_ value: String) -> Self {
    Self(text: value, imageAssetPath: nil, filePaths: nil)
  }

  static func image(assetPath: String) -> Self {
    Self(text: nil, imageAssetPath: assetPath, filePaths: nil)
  }

  static func file(paths: [String]) -> Self {
    Self(text: nil, imageAssetPath: nil, filePaths: paths)
  }
}
