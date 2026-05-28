import AppKit
import ApplicationServices
import Foundation

final class AccessibilityPasteTrigger {
  func isPermissionGranted() -> Bool {
    AXIsProcessTrusted()
  }

  func requestPermissionIfNeeded() -> Bool {
    let promptKey = "AXTrustedCheckOptionPrompt" as CFString
    let options = [
      promptKey: true,
    ] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  func openSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  func triggerPaste() {
    guard isPermissionGranted() else {
      _ = requestPermissionIfNeeded()
      return
    }

    guard
      let source = CGEventSource(stateID: .hidSystemState),
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: 9,
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: 9,
        keyDown: false
      )
    else {
      return
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }
}
