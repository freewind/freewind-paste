import SwiftUI

struct TextPreviewView: View {
  @EnvironmentObject private var appState: AppState
  let item: ClipItem
  var showsHeader: Bool = true
  var showsMetrics: Bool = true
  var minEditorHeight: CGFloat = 44
  var maxEditorHeight: CGFloat = 260

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

      ZStack(alignment: .topLeading) {
        Text(measurementText)
          .font(.system(size: 14))
          .lineSpacing(4)
          .foregroundStyle(.clear)
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            GeometryReader { proxy in
              Color.clear
                .preference(key: TextHeightPreferenceKey.self, value: proxy.size.height)
            }
          )

        TextEditor(text: $draftText)
          .font(.system(size: 14))
          .scrollContentBackground(.hidden)
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: editorHeight)
      .background(Color(NSColor.textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .onAppear { syncFromItem() }
      .onChange(of: item.id) { _, _ in syncFromItem() }
      .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
      .onPreferenceChange(TextHeightPreferenceKey.self) { value in
        let nextHeight = min(max(value, minEditorHeight), maxEditorHeight)
        if abs(editorHeight - nextHeight) > 0.5 {
          editorHeight = nextHeight
        }
      }
      .onDisappear { handleDisappear() }

      if showsMetrics {
        HStack(spacing: 6) {
          Text("\(lineCount) lines")
          Text("·")
          Text("\(draftText.count) chars")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
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
      appState.updateText(for: item.id, text: newValue)
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
    appState.updateText(for: item.id, text: draftText)
  }

  private var measurementText: String {
    draftText.isEmpty ? " " : "\(draftText)\n "
  }

  private var lineCount: Int {
    max(draftText.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
  }
}

private struct TextHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 44

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
