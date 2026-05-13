import AppKit
import Foundation

/// 持久化到 settings.json 的快捷键结构。
/// `keyCode` 用 macOS 虚拟键码，`modifiers` 用 Carbon modifier bitmask。
struct AppHotkey: Codable, Equatable {
  /// macOS 虚拟键码。
  /// 例：`9 = V`、`36 = Return`、`48 = Tab`、`51 = Delete`、`53 = Escape`、`125/126 = Down/Up`
  var keyCode: UInt32
  /// Carbon modifier bitmask。
  /// 当前只用这 4 个值：`256 = Command`、`512 = Shift`、`2048 = Option`、`4096 = Control`
  var modifiers: UInt32

  static let `default` = Self(
    keyCode: 9, // `V`
    modifiers: 256 | 512 // `Command + Shift`
  )

  var displayName: String {
    var parts: [String] = []
    if modifiers & 256 != 0 { parts.append("⌘") } // Command
    if modifiers & 512 != 0 { parts.append("⇧") } // Shift
    if modifiers & 2048 != 0 { parts.append("⌥") } // Option
    if modifiers & 4096 != 0 { parts.append("⌃") } // Control
    return parts.joined() + Self.keyName(for: keyCode)
  }

  func matches(_ event: NSEvent) -> Bool {
    keyCode == UInt32(event.keyCode) && modifiers == Self.carbonFlags(for: event.modifierFlags)
  }

  static func carbonFlags(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
    var flags: UInt32 = 0
    if modifiers.contains(.command) { flags |= 256 } // Carbon commandKey
    if modifiers.contains(.shift) { flags |= 512 } // Carbon shiftKey
    if modifiers.contains(.option) { flags |= 2048 } // Carbon optionKey
    if modifiers.contains(.control) { flags |= 4096 } // Carbon controlKey
    return flags
  }

  private static func keyName(for keyCode: UInt32) -> String {
    // 常见虚拟键码到展示名的最小映射；未覆盖时回退成 `#keyCode`
    let mapping: [UInt32: String] = [
      0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
      8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
      16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 36: "↩",
      37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 48: "⇥", 49: "Space",
      51: "⌫", 53: "⎋", 76: "⌤", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    return mapping[keyCode] ?? "#\(keyCode)"
  }
}

enum PopupShortcutAction: String, CaseIterable, Codable, Identifiable {
  case closePopup
  case focusList
  case paste
  case nativePaste
  case focusPrevious
  case focusNext
  case expandPrevious
  case expandNext
  case jumpToTop
  case jumpToBottom
  case moveSelectionUp
  case moveSelectionDown
  case deleteSelection
  case deleteSelectionPermanently

  var id: String { rawValue }

  var title: String {
    switch self {
    case .closePopup:
      return "Close Popup"
    case .focusList:
      return "Focus List"
    case .paste:
      return "Paste"
    case .nativePaste:
      return "Native Paste"
    case .focusPrevious:
      return "Focus Previous"
    case .focusNext:
      return "Focus Next"
    case .expandPrevious:
      return "Expand Previous"
    case .expandNext:
      return "Expand Next"
    case .jumpToTop:
      return "Jump To Top"
    case .jumpToBottom:
      return "Jump To Bottom"
    case .moveSelectionUp:
      return "Move Selection Up"
    case .moveSelectionDown:
      return "Move Selection Down"
    case .deleteSelection:
      return "Delete Selection"
    case .deleteSelectionPermanently:
      return "Delete Permanently"
    }
  }
}

/// popup 内部动作的快捷键表。
/// 每个字段对应一个动作，值为该动作当前绑定的 `AppHotkey`。
struct PopupHotkeys: Codable, Equatable {
  var closePopup: AppHotkey
  var focusList: AppHotkey
  var paste: AppHotkey
  var nativePaste: AppHotkey
  var focusPrevious: AppHotkey
  var focusNext: AppHotkey
  var expandPrevious: AppHotkey
  var expandNext: AppHotkey
  var jumpToTop: AppHotkey
  var jumpToBottom: AppHotkey
  var moveSelectionUp: AppHotkey
  var moveSelectionDown: AppHotkey
  var deleteSelection: AppHotkey
  var deleteSelectionPermanently: AppHotkey

  private enum CodingKeys: String, CodingKey {
    case closePopup
    case focusList
    case paste
    case nativePaste
    case focusPrevious
    case focusNext
    case expandPrevious
    case expandNext
    case jumpToTop
    case jumpToBottom
    case moveSelectionUp
    case moveSelectionDown
    case deleteSelection
    case deleteSelectionPermanently
  }

  static let `default` = Self(
    closePopup: .init(keyCode: 53, modifiers: 0), // Escape
    focusList: .init(keyCode: 48, modifiers: 0), // Tab
    paste: .init(keyCode: 36, modifiers: 0), // Return
    nativePaste: .init(keyCode: 36, modifiers: 512), // Shift + Return
    focusPrevious: .init(keyCode: 126, modifiers: 0), // Up
    focusNext: .init(keyCode: 125, modifiers: 0), // Down
    expandPrevious: .init(keyCode: 126, modifiers: 512), // Shift + Up
    expandNext: .init(keyCode: 125, modifiers: 512), // Shift + Down
    jumpToTop: .init(keyCode: 126, modifiers: 256), // Command + Up
    jumpToBottom: .init(keyCode: 125, modifiers: 256), // Command + Down
    moveSelectionUp: .init(keyCode: 126, modifiers: 512 | 2048), // Shift + Option + Up
    moveSelectionDown: .init(keyCode: 125, modifiers: 512 | 2048), // Shift + Option + Down
    deleteSelection: .init(keyCode: 51, modifiers: 0), // Delete
    deleteSelectionPermanently: .init(keyCode: 51, modifiers: 256) // Command + Delete
  )

  init(
    closePopup: AppHotkey = Self.default.closePopup,
    focusList: AppHotkey = Self.default.focusList,
    paste: AppHotkey = Self.default.paste,
    nativePaste: AppHotkey = Self.default.nativePaste,
    focusPrevious: AppHotkey = Self.default.focusPrevious,
    focusNext: AppHotkey = Self.default.focusNext,
    expandPrevious: AppHotkey = Self.default.expandPrevious,
    expandNext: AppHotkey = Self.default.expandNext,
    jumpToTop: AppHotkey = Self.default.jumpToTop,
    jumpToBottom: AppHotkey = Self.default.jumpToBottom,
    moveSelectionUp: AppHotkey = Self.default.moveSelectionUp,
    moveSelectionDown: AppHotkey = Self.default.moveSelectionDown,
    deleteSelection: AppHotkey = Self.default.deleteSelection,
    deleteSelectionPermanently: AppHotkey = Self.default.deleteSelectionPermanently
  ) {
    self.closePopup = closePopup
    self.focusList = focusList
    self.paste = paste
    self.nativePaste = nativePaste
    self.focusPrevious = focusPrevious
    self.focusNext = focusNext
    self.expandPrevious = expandPrevious
    self.expandNext = expandNext
    self.jumpToTop = jumpToTop
    self.jumpToBottom = jumpToBottom
    self.moveSelectionUp = moveSelectionUp
    self.moveSelectionDown = moveSelectionDown
    self.deleteSelection = deleteSelection
    self.deleteSelectionPermanently = deleteSelectionPermanently
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    closePopup = try container.decodeIfPresent(AppHotkey.self, forKey: .closePopup) ?? Self.default.closePopup
    focusList = try container.decodeIfPresent(AppHotkey.self, forKey: .focusList) ?? Self.default.focusList
    paste = try container.decodeIfPresent(AppHotkey.self, forKey: .paste) ?? Self.default.paste
    nativePaste = try container.decodeIfPresent(AppHotkey.self, forKey: .nativePaste) ?? Self.default.nativePaste
    focusPrevious = try container.decodeIfPresent(AppHotkey.self, forKey: .focusPrevious) ?? Self.default.focusPrevious
    focusNext = try container.decodeIfPresent(AppHotkey.self, forKey: .focusNext) ?? Self.default.focusNext
    expandPrevious = try container.decodeIfPresent(AppHotkey.self, forKey: .expandPrevious) ?? Self.default.expandPrevious
    expandNext = try container.decodeIfPresent(AppHotkey.self, forKey: .expandNext) ?? Self.default.expandNext
    jumpToTop = try container.decodeIfPresent(AppHotkey.self, forKey: .jumpToTop) ?? Self.default.jumpToTop
    jumpToBottom = try container.decodeIfPresent(AppHotkey.self, forKey: .jumpToBottom) ?? Self.default.jumpToBottom
    moveSelectionUp = try container.decodeIfPresent(AppHotkey.self, forKey: .moveSelectionUp) ?? Self.default.moveSelectionUp
    moveSelectionDown = try container.decodeIfPresent(AppHotkey.self, forKey: .moveSelectionDown) ?? Self.default.moveSelectionDown
    deleteSelection = try container.decodeIfPresent(AppHotkey.self, forKey: .deleteSelection) ?? Self.default.deleteSelection
    deleteSelectionPermanently = try container.decodeIfPresent(AppHotkey.self, forKey: .deleteSelectionPermanently) ?? Self.default.deleteSelectionPermanently
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(closePopup, forKey: .closePopup)
    try container.encode(focusList, forKey: .focusList)
    try container.encode(paste, forKey: .paste)
    try container.encode(nativePaste, forKey: .nativePaste)
    try container.encode(focusPrevious, forKey: .focusPrevious)
    try container.encode(focusNext, forKey: .focusNext)
    try container.encode(expandPrevious, forKey: .expandPrevious)
    try container.encode(expandNext, forKey: .expandNext)
    try container.encode(jumpToTop, forKey: .jumpToTop)
    try container.encode(jumpToBottom, forKey: .jumpToBottom)
    try container.encode(moveSelectionUp, forKey: .moveSelectionUp)
    try container.encode(moveSelectionDown, forKey: .moveSelectionDown)
    try container.encode(deleteSelection, forKey: .deleteSelection)
    try container.encode(deleteSelectionPermanently, forKey: .deleteSelectionPermanently)
  }

  func hotkey(for action: PopupShortcutAction) -> AppHotkey {
    switch action {
    case .closePopup:
      return closePopup
    case .focusList:
      return focusList
    case .paste:
      return paste
    case .nativePaste:
      return nativePaste
    case .focusPrevious:
      return focusPrevious
    case .focusNext:
      return focusNext
    case .expandPrevious:
      return expandPrevious
    case .expandNext:
      return expandNext
    case .jumpToTop:
      return jumpToTop
    case .jumpToBottom:
      return jumpToBottom
    case .moveSelectionUp:
      return moveSelectionUp
    case .moveSelectionDown:
      return moveSelectionDown
    case .deleteSelection:
      return deleteSelection
    case .deleteSelectionPermanently:
      return deleteSelectionPermanently
    }
  }

  mutating func set(_ hotkey: AppHotkey, for action: PopupShortcutAction) {
    switch action {
    case .closePopup:
      closePopup = hotkey
    case .focusList:
      focusList = hotkey
    case .paste:
      paste = hotkey
    case .nativePaste:
      nativePaste = hotkey
    case .focusPrevious:
      focusPrevious = hotkey
    case .focusNext:
      focusNext = hotkey
    case .expandPrevious:
      expandPrevious = hotkey
    case .expandNext:
      expandNext = hotkey
    case .jumpToTop:
      jumpToTop = hotkey
    case .jumpToBottom:
      jumpToBottom = hotkey
    case .moveSelectionUp:
      moveSelectionUp = hotkey
    case .moveSelectionDown:
      moveSelectionDown = hotkey
    case .deleteSelection:
      deleteSelection = hotkey
    case .deleteSelectionPermanently:
      deleteSelectionPermanently = hotkey
    }
  }
}

struct AppSettings: Codable, Equatable {
  var hotkey: AppHotkey
  var launchAtLogin: Bool
  var popupHotkeys: PopupHotkeys

  private enum CodingKeys: String, CodingKey {
    case hotkey
    case launchAtLogin
    case popupHotkeys
  }

  static let `default` = Self(
    hotkey: .default,
    launchAtLogin: false,
    popupHotkeys: .default
  )

  init(
    hotkey: AppHotkey = .default,
    launchAtLogin: Bool = false,
    popupHotkeys: PopupHotkeys = .default
  ) {
    self.hotkey = hotkey
    self.launchAtLogin = launchAtLogin
    self.popupHotkeys = popupHotkeys
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    hotkey = try container.decodeIfPresent(AppHotkey.self, forKey: .hotkey) ?? .default
    launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    popupHotkeys = try container.decodeIfPresent(PopupHotkeys.self, forKey: .popupHotkeys) ?? .default
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hotkey, forKey: .hotkey)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
    try container.encode(popupHotkeys, forKey: .popupHotkeys)
  }
}
