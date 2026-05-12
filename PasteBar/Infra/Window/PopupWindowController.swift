import AppKit
import SwiftUI

@MainActor
final class PopupWindowController: NSObject, NSWindowDelegate {
  private var window: NSWindow?

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

  private func makeWindow(appState: AppState) -> NSWindow {
    let root = HistoryView()
      .environmentObject(appState)
      .environmentObject(appState.store)

    let hostingView = NSHostingView(rootView: root)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "PasteBar"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = hostingView
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    return window
  }

  func windowWillClose(_ notification: Notification) {
    guard let window else {
      return
    }
    window.orderOut(nil)
  }
}
