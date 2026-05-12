import SwiftUI

struct TextPreviewView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem
  var showsHeader: Bool = true

  @State private var draftText: String = ""
  @State private var isSyncingFromItem = false
  @State private var saveTask: Task<Void, Never>?
  @State private var editorHeight: CGFloat = 44

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showsHeader {
        HStack {
          if !item.label.isEmpty {
            Text(item.label)
              .font(.headline)
              .lineLimit(1)
          }
        }
      }

      SyntaxHighlightingTextView(
        text: $draftText,
        identity: item.id,
        language: isJSON ? "json" : nil,
        isEditable: true,
        measuredHeight: $editorHeight
      )
      .id(item.id)
      .frame(maxWidth: .infinity)
      .frame(height: editorHeight)
      .background(Color(NSColor.textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .onAppear { syncFromItem() }
      .onChange(of: item.id) { _, _ in syncFromItem() }
      .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
      .onDisappear { handleDisappear() }

      HStack(spacing: 6) {
        Text("\(lineCount) lines")
        Text("·")
        Text("\(draftText.count) chars")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
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

  private var lineCount: Int {
    max(draftText.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
  }
}
