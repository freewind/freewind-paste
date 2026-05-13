import SwiftUI

struct PreviewPaneView: View {
  private enum MultiSelectionPreviewMode: String, CaseIterable {
    case split
    case merged

    var title: String {
      switch self {
      case .split:
        return "Split"
      case .merged:
        return "Merged"
      }
    }
  }

  @Environment(AppState.self) private var appState
  @Environment(ClipViewState.self) private var uiState
  @State private var multiSelectionMode: MultiSelectionPreviewMode = .split
  @State private var mergedDraftText: String = ""
  @State private var mergedSelectionSignature: String = ""

  var body: some View {
    @Bindable var appState = appState

    VStack(alignment: .leading, spacing: 12) {
      if showsToolbar {
        HStack(spacing: 10) {
          if uiState.selectedItems.count > 1 {
            Picker("", selection: $multiSelectionMode) {
              ForEach(MultiSelectionPreviewMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
              }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
          }

          Spacer()

          Button("Paste") {
            appState.pasteSelection(mode: .nativeShiftEnter)
          }
          .disabled(uiState.selectedItems.isEmpty)

          if hasImageSelection {
            Picker("Image Output", selection: $appState.imageOutputMode) {
              ForEach(ImageOutputMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
              }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
          }
        }
      }

      Group {
        if uiState.selectedItems.count > 1, multiSelectionMode == .merged {
          mergedSelectionContent
        } else if uiState.selectedItems.count > 1 {
          multiSelectionContent
        } else if let item = uiState.focusedItem {
          content(item: item)
        } else {
          ContentUnavailableView("No Selection", systemImage: "cursorarrow.click")
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      syncMergedDraft()
    }
    .onChange(of: currentSelectionSignature) { _, _ in
      syncMergedDraft()
    }
  }

  private var multiSelectionContent: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(Array(uiState.selectedItems.enumerated()), id: \.element.id) { index, item in
          VStack(alignment: .leading, spacing: 10) {
            if item.kind != .text {
              HStack {
                Text(headerTitle(for: item, index: index + 1))
                  .font(.headline)
                  .lineLimit(1)
                Spacer()
                Text(headerSummary(for: item))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            multiSelectionItemContent(item, index: index + 1)
          }
          .padding(12)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }
  }

  private var mergedSelectionContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("\(uiState.selectedItems.count) items")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("Local scratch")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      TextEditor(text: $mergedDraftText)
        .font(.system(size: 14))
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func content(item: ClipItem) -> some View {
    switch item.kind {
    case .text:
      TextPreviewView(
        item: item,
        minEditorHeight: 180,
        maxEditorHeight: 1_200,
        expandsToFill: true
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    case .image:
      VStack(alignment: .leading, spacing: 10) {
        metaHeader(item: item)
        ImagePreviewView(
          item: item,
          imageAssetStore: appState.imageAssetStore,
          outputMode: appState.imageOutputMode,
          compact: false
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    case .file:
      VStack(alignment: .leading, spacing: 10) {
        metaHeader(item: item)
        FilePreviewView(item: item, compact: false)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  @ViewBuilder
  private func multiSelectionItemContent(_ item: ClipItem, index: Int) -> some View {
    switch item.kind {
    case .text:
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("\(index).")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Text(headerSummary(for: item))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        CompactTextPreviewView(
          text: item.content.text ?? "",
          minHeight: 36,
          maxHeight: 320
        )
      }
    case .image:
      ImagePreviewView(
        item: item,
        imageAssetStore: appState.imageAssetStore,
        outputMode: appState.imageOutputMode,
        compact: true
      )
    case .file:
      FilePreviewView(item: item, compact: true)
    }
  }

  private var hasImageSelection: Bool {
    let items = uiState.selectedItems.isEmpty
      ? [uiState.focusedItem].compactMap { $0 }
      : uiState.selectedItems
    return items.contains { $0.kind == .image }
  }

  private var showsToolbar: Bool {
    uiState.focusedItem != nil || uiState.selectedItems.count > 1 || hasImageSelection
  }

  private var currentSelectionSignature: String {
    uiState.selectedItems
      .map { item in
        let updateToken = item.updatedAt.timeIntervalSince1970
        return "\(item.id)|\(updateToken)"
      }
      .joined(separator: "\u{1F}")
  }

  private func metaHeader(item: ClipItem) -> some View {
    HStack {
      if !item.label.isEmpty {
        Text(item.label)
          .font(.headline)
      }
      Spacer()
      Text(headerSummary(for: item))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func headerTitle(for item: ClipItem, index: Int) -> String {
    let label = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
    if !label.isEmpty {
      return "\(index). \(label)"
    }
    switch item.kind {
    case .text:
      return "\(index). \(item.normalizedTextPreview)"
    case .image:
      let width = item.meta.imageWidth ?? 0
      let height = item.meta.imageHeight ?? 0
      return "\(index). \(width)x\(height)"
    case .file:
      return "\(index). \(item.meta.fileName ?? "File")"
    }
  }

  private func headerSummary(for item: ClipItem) -> String {
    switch item.kind {
    case .text:
      let text = item.content.text ?? ""
      return "\(text.count) chars"
    case .image:
      let width = item.meta.imageWidth ?? 0
      let height = item.meta.imageHeight ?? 0
      let bytes = ByteCountFormatter.string(fromByteCount: item.meta.imageByteSize ?? 0, countStyle: .file)
      return "\(width)x\(height) · \(bytes)"
    case .file:
      let count = item.meta.fileCount ?? item.content.filePaths?.count ?? 0
      let size = ByteCountFormatter.string(fromByteCount: item.meta.fileSize ?? 0, countStyle: .file)
      return "\(count) items · \(size)"
    }
  }

  private func syncMergedDraft() {
    let signature = currentSelectionSignature
    guard signature != mergedSelectionSignature else {
      return
    }
    mergedSelectionSignature = signature
    mergedDraftText = mergedText(for: uiState.selectedItems)
  }

  private func mergedText(for items: [ClipItem]) -> String {
    items
      .map(mergedBlock(for:))
      .joined(separator: "\n\n")
  }

  private func mergedBlock(for item: ClipItem) -> String {
    switch item.kind {
    case .text:
      return item.content.text ?? ""
    case .image:
      let width = item.meta.imageWidth ?? 0
      let height = item.meta.imageHeight ?? 0
      return "[Image \(width)x\(height)]"
    case .file:
      return (item.content.filePaths ?? []).joined(separator: "\n")
    }
  }
}

private struct CompactTextPreviewView: View {
  let text: String
  let minHeight: CGFloat
  let maxHeight: CGFloat

  @State private var contentHeight: CGFloat = 44

  var body: some View {
    ZStack(alignment: .topLeading) {
      Text(measurementText)
        .font(.system(size: 14))
        .lineSpacing(4)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.clear)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          GeometryReader { proxy in
            Color.clear
              .preference(key: CompactTextPreviewHeightPreferenceKey.self, value: proxy.size.height)
          }
        )

      if shouldScroll {
        ScrollView {
          contentText
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        contentText
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: containerHeight, alignment: .topLeading)
    .background(Color(NSColor.textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .onPreferenceChange(CompactTextPreviewHeightPreferenceKey.self) { value in
      if abs(contentHeight - value) > 0.5 {
        contentHeight = value
      }
    }
  }

  private var contentText: some View {
    Text(text.isEmpty ? " " : text)
      .font(.system(size: 14))
      .lineSpacing(4)
      .textSelection(.enabled)
  }

  private var measurementText: String {
    text.isEmpty ? " " : text
  }

  private var containerHeight: CGFloat {
    min(max(contentHeight, minHeight), maxHeight)
  }

  private var shouldScroll: Bool {
    contentHeight > maxHeight
  }
}

private struct CompactTextPreviewHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 44

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
