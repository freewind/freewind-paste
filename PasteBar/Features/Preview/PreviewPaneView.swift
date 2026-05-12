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
              Text("\(index + 1). \(item.label.isEmpty ? item.titleText : item.label)")
                .font(.headline)
                .lineLimit(1)
              Spacer()
              Text(item.kind.rawValue.capitalized)
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
      TextPreviewView(item: item)
        .frame(minHeight: 160)
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
      Text(item.label.isEmpty ? item.titleText : item.label)
        .font(.headline)
      Spacer()
      Text(item.kind.rawValue.capitalized)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
