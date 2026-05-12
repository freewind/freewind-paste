import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
  @EnvironmentObject private var appState: AppState
  @State private var isRecording = false
  @State private var monitor: Any?
  @State private var feedbackText: String = ""
  @State private var feedbackTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(isRecording ? "Listening..." : displayName(for: appState.settings.hotkey))
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(isRecording ? .secondary : .primary)
        Spacer()
        Button(isRecording ? "Cancel" : "Record") {
          toggleRecording()
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(isRecording ? Color.accentColor.opacity(0.08) : Color(NSColor.textBackgroundColor))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))

      if !feedbackText.isEmpty {
        Text(feedbackText)
          .font(.caption)
          .foregroundStyle(.secondary)
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
    feedbackText = "Press modifiers + key, Esc to cancel."
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if event.keyCode == 53 {
        stopRecording()
        feedbackText = "Recording cancelled."
        return nil
      }

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
      showFeedback("Saved: \(displayName(for: appState.settings.hotkey))")
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

  private func showFeedback(_ text: String) {
    feedbackTask?.cancel()
    feedbackText = text
    feedbackTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.2))
      guard !Task.isCancelled else {
        return
      }
      if feedbackText == text {
        feedbackText = ""
      }
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
