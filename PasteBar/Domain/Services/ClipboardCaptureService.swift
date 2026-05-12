import Foundation

final class ClipboardCaptureService {
  private let watcher: PasteboardWatcher
  private let parser: ClipboardParseService

  init(
    watcher: PasteboardWatcher = PasteboardWatcher(),
    parser: ClipboardParseService
  ) {
    self.watcher = watcher
    self.parser = parser
  }

  func start(onCapture: @escaping (ClipItem) -> Void) {
    watcher.start {
      guard let item = self.parser.parse() else {
        return
      }
      onCapture(item)
    }
  }

  func stop() {
    watcher.stop()
  }
}
