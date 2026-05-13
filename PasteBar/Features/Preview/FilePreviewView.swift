import SwiftUI

struct FilePreviewView: View {
  @EnvironmentObject private var appState: AppState
  let item: ClipItem
  var compact: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      let paths = item.content.filePaths ?? []

      HStack(spacing: 10) {
        Text("\(item.meta.fileCount ?? paths.count) items")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Menu {
          Button("Open") {
            appState.openItemResource(item)
          }
          .disabled(paths.isEmpty)
          Button("Reveal in Finder") {
            appState.revealItemResource(item)
          }
          .disabled(paths.isEmpty)
          Button("Save As") {
            appState.saveItemAs(item)
          }
          .disabled(paths.isEmpty)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 14))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
      }

      ScrollView {
        Text(paths.joined(separator: "\n"))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(
        maxWidth: .infinity,
        minHeight: compact ? nil : 260,
        maxHeight: compact ? 220 : .infinity,
        alignment: .topLeading
      )
      .padding(10)
      .background(Color.secondary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
      .onTapGesture {
        appState.openItemResource(item)
      }

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
        GridRow {
          Text("Count")
          Text("\(item.meta.fileCount ?? paths.count)")
        }
        GridRow {
          Text("Exists")
          Text((item.meta.fileExists ?? false) ? "Yes" : "No")
        }
        GridRow {
          Text("Size")
          Text(ByteCountFormatter.string(fromByteCount: item.meta.fileSize ?? 0, countStyle: .file))
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
  }
}
