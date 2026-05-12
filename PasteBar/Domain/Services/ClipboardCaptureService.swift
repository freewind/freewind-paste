import Foundation

final class ClipboardCaptureService {
  private let watcher: PasteboardWatcher
  private let parser: ClipboardParseService
  private let copyCommandMonitor: CopyCommandMonitor

  init(
    watcher: PasteboardWatcher = PasteboardWatcher(),
    parser: ClipboardParseService,
    copyCommandMonitor: CopyCommandMonitor = CopyCommandMonitor()
  ) {
    self.watcher = watcher
    self.parser = parser
    self.copyCommandMonitor = copyCommandMonitor
  }

  func start(onCapture: @escaping (ClipItem) -> Void) {
    copyCommandMonitor.start()
    watcher.start {
      guard let item = self.parser.parse() else {
        return
      }
      onCapture(item)
    }
  }

  func stop() {
    copyCommandMonitor.stop()
    watcher.stop()
  }
}
