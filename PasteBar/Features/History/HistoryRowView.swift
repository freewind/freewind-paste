import SwiftUI

struct HistoryRowView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 4) {
      checkButton

      favoriteButton

      leadingPreview

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 12))
          .lineLimit(1)
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .padding(.vertical, 0)
    .onHover { isHovering = $0 }
  }

  @ViewBuilder
  private var leadingPreview: some View {
    switch item.kind {
    case .image:
      if
        let path = item.content.imageAssetPath,
        let image = appState.imageAssetStore.load(relativePath: path)
      {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 22, height: 22)
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: 4))
      } else {
        Image(systemName: "photo")
          .font(.system(size: 10))
          .frame(width: 22, height: 22)
          .foregroundStyle(.secondary)
      }
    case .text:
      Image(systemName: "text.alignleft")
        .font(.system(size: 10))
        .frame(width: 12, height: 12)
        .foregroundStyle(.secondary)
    case .file:
      Image(systemName: "doc")
        .font(.system(size: 10))
        .frame(width: 12, height: 12)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var checkButton: some View {
    Button {
      store.toggleChecked(item.id)
    } label: {
      Image(systemName: store.checkedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
        .font(.system(size: 11))
        .foregroundStyle(store.checkedIDs.contains(item.id) ? Color.accentColor : Color.secondary)
        .frame(width: 12, height: 12)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var favoriteButton: some View {
    if store.currentTab == .trash {
      Color.clear
        .frame(width: 12, height: 12)
    } else {
      Button {
        store.toggleFavorite(for: item.id)
        appState.persistItems()
      } label: {
        Image(systemName: item.favorite ? "star.fill" : "star")
          .font(.system(size: 11))
          .foregroundStyle(item.favorite ? .yellow : .secondary)
          .frame(width: 12, height: 12)
          .opacity(item.favorite ? 1 : 0.45)
      }
      .buttonStyle(.plain)
    }
  }

  private var title: String {
    if !item.label.isEmpty {
      return item.label
    }
    return item.titleText
  }

  private var subtitle: String {
    switch item.kind {
    case .text:
      return ""
    case .image:
      return "\(item.meta.imageWidth ?? 0)x\(item.meta.imageHeight ?? 0)"
    case .file:
      let count = item.meta.fileCount ?? 1
      return count == 1 ? (item.content.filePaths?.first ?? "") : "\(count) files"
    }
  }
}
