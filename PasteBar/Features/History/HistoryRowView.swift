import SwiftUI

struct HistoryRowView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  let item: ClipItem
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 6) {
      favoriteButton

      Image(systemName: iconName)
        .font(.caption)
        .frame(width: 12)
        .foregroundStyle(.secondary)

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
    .padding(.vertical, 1)
    .onHover { isHovering = $0 }
  }

  private var iconName: String {
    switch item.kind {
    case .text:
      return "text.alignleft"
    case .image:
      return "photo"
    case .file:
      return "doc"
    }
  }

  @ViewBuilder
  private var favoriteButton: some View {
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
