import AppKit
import SwiftUI

@MainActor
final class PopupWindowController {
  private var panel: NSPanel?

  func toggle(with appState: AppState) {
    if panel == nil {
      panel = makePanel(appState: appState)
    }

    guard let panel else {
      return
    }

    if panel.isVisible {
      panel.orderOut(nil)
      appState.isPopupVisible = false
    } else {
      panel.center()
      panel.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      appState.isPopupVisible = true
    }
  }

  private func makePanel(appState: AppState) -> NSPanel {
    let root = HistoryView()
      .environmentObject(appState)
      .environmentObject(appState.store)

    let hostingView = NSHostingView(rootView: root)
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.contentView = hostingView
    return panel
  }
}
