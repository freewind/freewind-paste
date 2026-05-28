import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var appState: AppState?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    Task { @MainActor [weak self] in
      self?.appState?.showPopup()
    }
    return true
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    Task { @MainActor [weak self] in
      self?.appState?.activatePopup()
    }
  }
}
