import AppKit
import Foundation

final class PasteboardWatcher {
  private let pasteboard: NSPasteboard
  private var timer: Timer?
  private var lastChangeCount: Int
  private var onChange: (() -> Void)?

  init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
    lastChangeCount = pasteboard.changeCount
  }

  func start(interval: TimeInterval = 0.35, onChange: @escaping () -> Void) {
    stop()
    self.onChange = onChange
    timer = Timer.scheduledTimer(
      timeInterval: interval,
      target: self,
      selector: #selector(handleTimerTick),
      userInfo: nil,
      repeats: true
    )
    RunLoop.main.add(timer!, forMode: .common)
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    onChange = nil
  }

  @objc
  private func handleTimerTick() {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastChangeCount else {
      return
    }
    lastChangeCount = changeCount
    onChange?()
  }
}
