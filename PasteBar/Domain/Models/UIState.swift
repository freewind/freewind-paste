import Foundation

enum MainTab: String, CaseIterable {
  case history
  case favorites
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
