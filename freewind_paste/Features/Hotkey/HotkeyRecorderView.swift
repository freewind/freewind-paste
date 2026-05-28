import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
  let title: String
  let hotkey: AppHotkey
  let requiresModifier: Bool
  let onChange: (AppHotkey) -> Void

  @State private var isRecording = false
  @State private var monitor: Any?
  @State private var feedbackText: String = ""
  @State private var feedbackTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Text(isRecording ? "Listening..." : hotkey.displayName)
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
    feedbackText = requiresModifier
      ? "Press modifiers + key, Esc to cancel."
      : "Press key combo, Esc to cancel."

    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if event.keyCode == 53 {
        stopRecording()
        feedbackText = "Recording cancelled."
        return nil
      }

      let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
      if requiresModifier && modifiers.isEmpty {
        showFeedback("Modifiers required.")
        return nil
      }

      let newHotkey = AppHotkey(
        keyCode: UInt32(event.keyCode),
        modifiers: AppHotkey.carbonFlags(for: modifiers)
      )
      onChange(newHotkey)
      showFeedback("Saved: \(newHotkey.displayName)")
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
}
