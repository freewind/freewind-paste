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

  func focusHistoryList() {
    guard let window else {
      return
    }

    if let tableView = window.contentView?.firstSubview(where: { view in
      view is NSTableView || view is NSOutlineView
    }) {
      window.makeFirstResponder(tableView)
      return
    }

    if let scrollView = window.contentView?.firstSubview(where: { $0 is NSScrollView }) {
      window.makeFirstResponder(scrollView)
    }
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

final class TransientPreviewPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class TransientImagePreviewController: NSObject, NSWindowDelegate {
  private var window: NSPanel?

  func show(image: NSImage, title: String) {
    if window == nil {
      window = makeWindow()
    }

    guard let window else {
      return
    }

    let width = min(max(image.size.width, 320), 1100)
    let height = min(max(image.size.height, 220), 820)

    window.title = title
    window.contentView = NSHostingView(
      rootView: TransientImagePreviewContent(image: image)
    )
    window.setContentSize(NSSize(width: width, height: height))
    window.center()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    window?.orderOut(nil)
  }

  private func makeWindow() -> NSPanel {
    let window = TransientPreviewPanel(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isFloatingPanel = true
    window.hidesOnDeactivate = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.transient, .moveToActiveSpace]
    window.delegate = self
    return window
  }
}

private struct TransientImagePreviewContent: View {
  let image: NSImage

  var body: some View {
    ZStack {
      Color.black.opacity(0.92)
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .padding(20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private extension NSView {
  func firstSubview(where predicate: (NSView) -> Bool) -> NSView? {
    if predicate(self) {
      return self
    }

    for subview in subviews {
      if let matched = subview.firstSubview(where: predicate) {
        return matched
      }
    }

    return nil
  }
}
