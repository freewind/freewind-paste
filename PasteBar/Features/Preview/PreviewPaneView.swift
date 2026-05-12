import SwiftUI

struct PreviewPaneView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if hasImageSelection {
        HStack {
          Spacer()
          Picker("Image Output", selection: $appState.imageOutputMode) {
            ForEach(ImageOutputMode.allCases, id: \.self) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .frame(width: 180)
        }
      }

      Group {
        if store.selectedItems.count > 1 {
          multiSelectionContent
        } else if let item = store.focusedItem {
          content(item: item)
        } else {
          ContentUnavailableView("No Selection", systemImage: "cursorarrow.click")
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var multiSelectionContent: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(Array(store.selectedItems.enumerated()), id: \.element.id) { index, item in
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(headerTitle(for: item, index: index + 1))
                .font(.headline)
                .lineLimit(1)
              Spacer()
              Text(headerSummary(for: item))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            multiSelectionItemContent(item)
          }
          .padding(12)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }
  }

  @ViewBuilder
  private func content(item: ClipItem) -> some View {
    switch item.kind {
    case .text:
      TextPreviewView(item: item)
    case .image:
      VStack(alignment: .leading, spacing: 10) {
        metaHeader(item: item)
        ImagePreviewView(
          item: item,
          imageAssetStore: appState.imageAssetStore,
          outputMode: appState.imageOutputMode
        )
      }
    case .file:
      VStack(alignment: .leading, spacing: 10) {
        metaHeader(item: item)
        FilePreviewView(item: item)
      }
    }
  }

  @ViewBuilder
  private func multiSelectionItemContent(_ item: ClipItem) -> some View {
    switch item.kind {
    case .text:
      TextPreviewView(item: item, showsHeader: false)
    case .image:
      ImagePreviewView(
        item: item,
        imageAssetStore: appState.imageAssetStore,
        outputMode: appState.imageOutputMode
      )
    case .file:
      FilePreviewView(item: item)
    }
  }

  private var hasImageSelection: Bool {
    let items = store.selectedItems.isEmpty
      ? [store.focusedItem].compactMap { $0 }
      : store.selectedItems
    return items.contains { $0.kind == .image }
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
      let lines = max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
      return "\(text.count) chars · \(lines) lines"
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
}
