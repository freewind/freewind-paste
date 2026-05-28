import AppKit
import Foundation

final class CopyCommandMonitor {
  private var localMonitor: Any?
  private var globalMonitor: Any?
  private var lastCopyLikeAt = Date.distantPast

  func start() {
    stop()
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event)
      return event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event)
    }
  }

  func stop() {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
    }
  }

  func shouldAcceptChange(now: Date = .now) -> Bool {
    now.timeIntervalSince(lastCopyLikeAt) <= 1.2
  }

  private func handle(_ event: NSEvent) {
    guard event.modifierFlags.contains(.command) else {
      return
    }
    if event.keyCode == 8 || event.keyCode == 7 {
      lastCopyLikeAt = .now
    }
  }
}
