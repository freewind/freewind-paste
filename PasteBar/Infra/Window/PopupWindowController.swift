import AppKit
import SwiftUI

final class BorderlessPopupWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

@MainActor
final class PopupWindowController: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  var currentWindow: NSWindow? { window }

  func show(with appState: AppState) {
    if window == nil {
      window = makeWindow(appState: appState)
    }

    guard let window else {
      return
    }

    if !window.isVisible {
      window.center()
    }

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    appState.isPopupVisible = true
  }

  func hide() {
    guard let window else {
      return
    }
    window.orderOut(nil)
  }

  private func makeWindow(appState: AppState) -> NSWindow {
    let root = HistoryView()
      .environmentObject(appState)
      .environmentObject(appState.uiState)
      .environmentObject(appState.store)

    let hostingView = NSHostingView(rootView: root)
    let window = BorderlessPopupWindow(
      contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .windowBackgroundColor
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.isMovableByWindowBackground = true
    window.contentView = hostingView
    return window
  }

  func windowWillClose(_ notification: Notification) {
    hide()
  }
}
