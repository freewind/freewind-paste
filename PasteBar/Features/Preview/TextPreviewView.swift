import SwiftUI

struct TextPreviewView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem

  @State private var draftText: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(item.meta.languageGuess ?? "plain text")
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.12))
          .clipShape(Capsule())
        Spacer()
      }

      SyntaxHighlightingTextView(
        text: $draftText,
        language: item.meta.languageGuess,
        isEditable: true
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 10))
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
