import SwiftUI

struct TextPreviewView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem

  @State private var draftText: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        if !item.label.isEmpty {
          Text(item.label)
            .font(.headline)
            .lineLimit(1)
        }

        Spacer()

        Text(item.meta.languageGuess ?? "plain text")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      SyntaxHighlightingTextView(
        text: $draftText,
        language: item.meta.languageGuess,
        isEditable: true
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(NSColor.textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .onAppear {
        draftText = item.content.text ?? ""
      }
      .onChange(of: item.id) { _, _ in
        draftText = item.content.text ?? ""
      }
      .onChange(of: draftText) { _, newValue in
        store.updateText(
          for: item.id,
          text: newValue,
          languageGuess: LanguageGuessService.guess(for: newValue)
        )
        appState.persistItems()
      }
    }
  }
}
