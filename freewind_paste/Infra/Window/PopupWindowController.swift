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

    if let tableView = historyListView() {
      window.makeFirstResponder(tableView)
      return
    }

    if let scrollView = historyListScrollView() {
      window.makeFirstResponder(scrollView)
    }
  }

  func activateHistoryListIfNeeded(for event: NSEvent) {
    guard
      let window,
      let scrollView = historyListScrollView()
    else {
      return
    }

    let location = scrollView.convert(event.locationInWindow, from: nil)
    guard scrollView.bounds.contains(location) else {
      return
    }

    if let tableView = historyListView() {
      window.makeFirstResponder(tableView)
      return
    }

    window.makeFirstResponder(scrollView)
  }

  private func makeWindow(appState: AppState) -> NSWindow {
    let root = HistoryView()
      .environment(appState)
      .environment(appState.uiState)

    let hostingView = NSHostingView(rootView: root)
    let window = BorderlessPopupWindow(
      contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .windowBackgroundColor
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 700, height: 460)
    window.delegate = self
    window.isMovableByWindowBackground = true
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.toolbar = nil
    window.contentView = hostingView
    return window
  }

  func windowWillClose(_ notification: Notification) {
    hide()
  }

  private func historyListView() -> NSView? {
    window?.contentView?.firstSubview(where: { view in
      view is NSTableView || view is NSOutlineView
    })
  }

  private func historyListScrollView() -> NSScrollView? {
    if let tableView = historyListView() {
      return tableView.enclosingScrollView
    }

    return window?.contentView?.firstSubview(where: { $0 is NSScrollView }) as? NSScrollView
  }
}

final class TransientPreviewPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) {
    orderOut(sender)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      orderOut(nil)
      return
    }

    super.keyDown(with: event)
  }
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
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isFloatingPanel = true
    window.hidesOnDeactivate = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.transient, .moveToActiveSpace]
    window.minSize = NSSize(width: 320, height: 220)
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
