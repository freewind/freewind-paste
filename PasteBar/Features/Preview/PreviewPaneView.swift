import SwiftUI

struct PreviewPaneView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    Group {
      if let item = store.focusedItem {
        VStack(alignment: .leading, spacing: 16) {
          header(item: item)

          if store.previewLocked {
            ContentUnavailableView("Preview Locked", systemImage: "lock")
          } else {
            switch item.kind {
            case .text:
              TextPreviewView(item: item)
            case .image:
              ImagePreviewView(item: item, imageAssetStore: appState.imageAssetStore)
            case .file:
              FilePreviewView(item: item)
            }
          }
        }
      } else {
        ContentUnavailableView("No Selection", systemImage: "cursorarrow.click")
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func header(item: ClipItem) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(item.kind.rawValue.capitalized)
          .font(.headline)
        Spacer()
        Button {
          store.toggleFavorite(for: item.id)
          appState.persistItems()
        } label: {
          Image(systemName: item.favorite ? "star.fill" : "star")
        }
        .buttonStyle(.plain)
      }

      TextField(
        "Label",
        text: Binding(
          get: { store.focusedItem?.label ?? "" },
          set: { newValue in
            store.updateLabel(for: item.id, label: newValue)
            appState.persistItems()
          }
        )
      )
    }
  }
}
