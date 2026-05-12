import SwiftUI

struct FilePreviewView: View {
  let item: ClipItem

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      let paths = item.content.filePaths ?? []

      ScrollView {
        Text(paths.joined(separator: "\n"))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 220)
      .padding(10)
      .background(Color.secondary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10))

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
  }
}
