import AppKit
import Foundation

final class PasteboardWatcher {
  private let pasteboard: NSPasteboard
  private var timer: Timer?
  private var lastChangeCount: Int

  init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
    lastChangeCount = pasteboard.changeCount
  }

  func start(interval: TimeInterval = 0.35, onChange: @escaping () -> Void) {
    stop()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self else {
        return
      }
      let changeCount = pasteboard.changeCount
      guard changeCount != lastChangeCount else {
        return
      }
      lastChangeCount = changeCount
      onChange()
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }
}
