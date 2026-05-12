import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private var statusItem: NSStatusItem?
  private var onOpen: (() -> Void)?
  private var onSettings: (() -> Void)?
  private var onQuit: (() -> Void)?
  private var contextMenu: NSMenu?

  func install(
    onOpen: @escaping () -> Void,
    onSettings: @escaping () -> Void,
    onQuit: @escaping () -> Void
  ) {
    guard statusItem == nil else {
      return
    }

    self.onOpen = onOpen
    self.onSettings = onSettings
    self.onQuit = onQuit

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item

    guard let button = item.button else {
      return
    }

    button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PasteBar")
    button.imagePosition = .imageOnly
    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  @objc
  private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      onOpen?()
      return
    }

    if event.type == .rightMouseUp {
      let menu = NSMenu()
      menu.delegate = self
      let openItem = menu.addItem(withTitle: "Open", action: #selector(openAction), keyEquivalent: "")
      openItem.target = self

      let settingsItem = menu.addItem(withTitle: "Settings", action: #selector(settingsAction), keyEquivalent: ",")
      settingsItem.target = self

      menu.addItem(.separator())

      let quitItem = menu.addItem(withTitle: "Quit", action: #selector(quitAction), keyEquivalent: "q")
      quitItem.target = self

      contextMenu = menu
      statusItem?.menu = menu
      statusItem?.button?.performClick(nil)
      return
    }

    onOpen?()
  }

  @objc
  private func openAction() {
    onOpen?()
  }

  @objc
  private func settingsAction() {
    onSettings?()
  }

  @objc
  private func quitAction() {
    onQuit?()
  }

  func menuDidClose(_ menu: NSMenu) {
    guard contextMenu === menu else {
      return
    }
    statusItem?.menu = nil
    contextMenu = nil
  }
}
