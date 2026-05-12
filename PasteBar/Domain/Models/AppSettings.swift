import Foundation

struct AppHotkey: Codable, Equatable {
  var keyCode: UInt32
  var modifiers: UInt32

  static let `default` = Self(
    keyCode: 9,
    modifiers: 256 | 512
  )
}

struct AppSettings: Codable, Equatable {
  var hotkey: AppHotkey
  var launchAtLogin: Bool
  var previewLocked: Bool

  static let `default` = Self(
    hotkey: .default,
    launchAtLogin: false,
    previewLocked: false
  )
}
