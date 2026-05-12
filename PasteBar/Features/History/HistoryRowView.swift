import SwiftUI

struct HistoryRowView: View {
  let item: ClipItem

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: iconName)
        .frame(width: 16)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(item.titleText)
            .lineLimit(1)
          if item.favorite {
            Image(systemName: "star.fill")
              .foregroundStyle(.yellow)
          }
        }
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.vertical, 4)
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

  private var subtitle: String {
    switch item.kind {
    case .text:
      return item.meta.languageGuess ?? "text"
    case .image:
      return "\(item.meta.imageWidth ?? 0)x\(item.meta.imageHeight ?? 0)"
    case .file:
      let count = item.meta.fileCount ?? 1
      return count == 1 ? (item.content.filePaths?.first ?? "") : "\(count) files"
    }
  }
}
