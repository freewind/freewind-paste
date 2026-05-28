import Foundation

enum PathNormalize {
  static func normalize(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
  }
}
