import Foundation

enum ClipKind: String, Codable, CaseIterable, Sendable {
  case text
  case image
  case file
}
