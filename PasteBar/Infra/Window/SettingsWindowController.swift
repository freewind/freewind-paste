import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
  private var window: NSWindow?

  func show(with appState: AppState) {
    if window == nil {
      window = makeWindow(appState: appState)
    }

    guard let window else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    window.center()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow(appState: AppState) -> NSWindow {
    let root = SettingsView()
      .environmentObject(appState)
      .environmentObject(appState.uiState)
      .environmentObject(appState.store)

    let hostingView = NSHostingView(rootView: root)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Settings"
    window.isReleasedWhenClosed = false
    window.contentView = hostingView
    return window
  }
}
