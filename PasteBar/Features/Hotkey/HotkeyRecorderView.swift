import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
  @EnvironmentObject private var appState: AppState
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    HStack {
      Text(displayName(for: appState.settings.hotkey))
        .font(.system(.body, design: .monospaced))
      Spacer()
      Button(isRecording ? "Press Keys" : "Record") {
        toggleRecording()
      }
    }
    .onDisappear {
      stopRecording()
    }
  }

  private func toggleRecording() {
    if isRecording {
      stopRecording()
      return
    }

    isRecording = true
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
      guard !modifiers.isEmpty else {
        return nil
      }

      appState.updateSettings {
        $0.hotkey = AppHotkey(
          keyCode: UInt32(event.keyCode),
          modifiers: carbonFlags(for: modifiers)
        )
      }
      stopRecording()
      return nil
    }
  }

  private func stopRecording() {
    isRecording = false
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private func displayName(for hotkey: AppHotkey) -> String {
    var parts: [String] = []
    if hotkey.modifiers & 256 != 0 { parts.append("⌘") }
    if hotkey.modifiers & 512 != 0 { parts.append("⇧") }
    if hotkey.modifiers & 2048 != 0 { parts.append("⌥") }
    if hotkey.modifiers & 4096 != 0 { parts.append("⌃") }
    return parts.joined() + keyName(for: hotkey.keyCode)
  }

  private func keyName(for keyCode: UInt32) -> String {
    let mapping: [UInt32: String] = [
      0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
      8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
      16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
      38: "J", 40: "K", 45: "N", 46: "M", 49: "Space"
    ]
    return mapping[keyCode] ?? "#\(keyCode)"
  }

  private func carbonFlags(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
    var flags: UInt32 = 0
    if modifiers.contains(.command) { flags |= 256 }
    if modifiers.contains(.shift) { flags |= 512 }
    if modifiers.contains(.option) { flags |= 2048 }
    if modifiers.contains(.control) { flags |= 4096 }
    return flags
  }
}
