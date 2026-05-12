import SwiftUI

struct PreviewPaneView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    Group {
      if let item = store.focusedItem {
        content(item: item)
      } else {
        ContentUnavailableView("No Selection", systemImage: "cursorarrow.click")
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func content(item: ClipItem) -> some View {
    if store.previewLocked {
      ContentUnavailableView("Preview Locked", systemImage: "lock")
    } else {
      switch item.kind {
      case .text:
        TextPreviewView(item: item)
      case .image:
        VStack(alignment: .leading, spacing: 10) {
          metaHeader(item: item)
          ImagePreviewView(item: item, imageAssetStore: appState.imageAssetStore)
        }
      case .file:
        VStack(alignment: .leading, spacing: 10) {
          metaHeader(item: item)
          FilePreviewView(item: item)
        }
      }
    }
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
