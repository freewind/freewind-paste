import Foundation

enum MainTab: String, CaseIterable {
  case history
  case favorites
  case trash
}

enum ClipKindFilter: String, CaseIterable {
  case all
  case text
  case image
  case file

  var title: String {
    switch self {
    case .all:
      return "All"
    case .text:
      return "Text"
    case .image:
      return "Image"
    case .file:
      return "File"
    }
  }
}

enum PasteMode {
  case normalEnter
  case nativeShiftEnter
}

enum ImageOutputMode: String, CaseIterable {
  case original
  case lowResolution

  var title: String {
    switch self {
    case .original:
      return "Original"
    case .lowResolution:
      return "Low"
    }
  }
}
