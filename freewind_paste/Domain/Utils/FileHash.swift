import CryptoKit
import Foundation

enum FileHash {
  static func sha256(data: Data) -> String {
    SHA256.hash(data: data)
      .compactMap { String(format: "%02x", $0) }
      .joined()
  }
}
