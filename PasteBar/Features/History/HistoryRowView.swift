import SwiftUI

struct HistoryRowView: View {
  enum DropLine: Equatable {
    case none
    case before
    case after
  }

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  let item: ClipItem
  var isDragActive: Bool = false
  var isDragged: Bool = false
  var dropLine: DropLine = .none
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 4) {
      checkButton

      favoriteButton

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          if !item.label.isEmpty {
            Text(item.label)
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(Color.secondary.opacity(0.12))
              .clipShape(Capsule())
          }

          Text(contentTitle)
            .font(.system(size: 12))
            .lineLimit(1)
        }

        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .padding(.horizontal, 12)
    .background(rowBackground)
    .overlay(alignment: .topLeading) {
      if dropLine == .before {
        dropIndicator
      }
    }
    .overlay(alignment: .bottomLeading) {
      if dropLine == .after {
        dropIndicator
      }
    }
    .opacity(isDragged ? 0.55 : 1)
    .onHover { isHovering = $0 }
  }

  @ViewBuilder
  private var checkButton: some View {
    Button {
      uiState.toggleChecked(item.id)
    } label: {
      Image(systemName: uiState.checkedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
        .font(.system(size: 11))
        .foregroundStyle(uiState.checkedIDs.contains(item.id) ? Color.accentColor : Color.secondary)
        .frame(width: 12, height: 12)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var favoriteButton: some View {
    if uiState.currentTab == .trash {
      Color.clear
        .frame(width: 12, height: 12)
    } else {
      Button {
        appState.toggleFavorite(for: item.id)
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

  private var contentTitle: String {
    return item.titleText
  }

  @ViewBuilder
  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(backgroundColor)
  }

  @ViewBuilder
  private var dropIndicator: some View {
    RoundedRectangle(cornerRadius: 999)
      .fill(Color.accentColor)
      .frame(height: 2)
      .padding(.horizontal, 2)
  }

  private var backgroundColor: Color {
    if isDragged {
      return Color.accentColor.opacity(0.10)
    }

    if dropLine != .none {
      return .clear
    }

    if uiState.focusedID == item.id {
      return Color.accentColor.opacity(0.16)
    }

    if uiState.selectedIDs.contains(item.id) {
      return Color.accentColor.opacity(0.10)
    }

    if isHovering && !isDragActive {
      return Color.secondary.opacity(0.06)
    }

    return .clear
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
