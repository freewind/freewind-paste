import SwiftUI

struct TextPreviewView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem

  @State private var draftText: String = ""
  @State private var isSyncingFromItem = false
  @State private var saveTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        if !item.label.isEmpty {
          Text(item.label)
            .font(.headline)
            .lineLimit(1)
        }

        Spacer()

        Text(isJSON ? "json" : "plain text")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if isJSON {
        SyntaxHighlightingTextView(
          text: $draftText,
          language: "json",
          isEditable: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { syncFromItem() }
        .onChange(of: item.id) { _, _ in syncFromItem() }
        .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
        .onDisappear { handleDisappear() }
      } else {
        TextEditor(text: $draftText)
          .font(.system(size: 13, design: .monospaced))
          .scrollContentBackground(.hidden)
          .padding(6)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(NSColor.textBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .onAppear { syncFromItem() }
          .onChange(of: item.id) { _, _ in syncFromItem() }
          .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
          .onDisappear { handleDisappear() }
      }
    }
  }

  private var isJSON: Bool {
    (item.meta.languageGuess ?? LanguageGuessService.guess(for: item.content.text ?? ""))?.lowercased() == "json"
  }

  private func handleDraftChange(_ newValue: String) {
    guard !isSyncingFromItem else {
      return
    }

    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else {
        return
      }
      store.updateText(
        for: item.id,
        text: newValue,
        languageGuess: LanguageGuessService.guess(for: newValue)
      )
      appState.persistItems()
    }
  }

  private func syncFromItem() {
    isSyncingFromItem = true
    draftText = item.content.text ?? ""
    DispatchQueue.main.async {
      isSyncingFromItem = false
    }
  }

  private func handleDisappear() {
    saveTask?.cancel()
    let current = item.content.text ?? ""
    guard draftText != current else {
      return
    }
    store.updateText(
      for: item.id,
      text: draftText,
      languageGuess: LanguageGuessService.guess(for: draftText)
    )
    appState.persistItems()
  }
}
