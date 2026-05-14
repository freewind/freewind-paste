import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private static let statusBarImage = makeStatusBarImage()

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

    button.image = Self.statusBarImage
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyDown
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

  private static func makeStatusBarImage() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else {
        return false
      }

      let body = NSBezierPath(
        roundedRect: NSRect(x: 2.5, y: 1.5, width: 13, height: 13.5),
        xRadius: 3.5,
        yRadius: 3.5
      )
      let clip = NSBezierPath(
        roundedRect: NSRect(x: 5, y: 11, width: 8, height: 5),
        xRadius: 2.3,
        yRadius: 2.3
      )
      let bar1 = NSBezierPath(
        roundedRect: NSRect(x: 5, y: 9, width: 8, height: 1.6),
        xRadius: 0.8,
        yRadius: 0.8
      )
      let bar2 = NSBezierPath(
        roundedRect: NSRect(x: 5, y: 6.2, width: 8, height: 1.6),
        xRadius: 0.8,
        yRadius: 0.8
      )
      let bar3 = NSBezierPath(
        roundedRect: NSRect(x: 5, y: 3.4, width: 8, height: 1.6),
        xRadius: 0.8,
        yRadius: 0.8
      )

      NSColor.black.setFill()
      body.fill()
      clip.fill()

      context.saveGState()
      context.setBlendMode(.clear)
      bar1.fill()
      bar2.fill()
      bar3.fill()
      context.restoreGState()

      return rect.intersects(body.bounds.union(clip.bounds))
    }
    image.isTemplate = true
    image.accessibilityDescription = "PasteBar"
    return image
  }
}
