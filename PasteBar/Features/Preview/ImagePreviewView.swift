import SwiftUI

struct ImagePreviewView: View {
  let item: ClipItem
  let imageAssetStore: ImageAssetStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if
        let path = item.content.imageAssetPath,
        let image = imageAssetStore.load(relativePath: path)
      {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: 320)
          .background(Color.black.opacity(0.03))
          .clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        ContentUnavailableView("Image Missing", systemImage: "photo")
      }

      HStack {
        Text("\(item.meta.imageWidth ?? 0)x\(item.meta.imageHeight ?? 0)")
        Spacer()
        Text(item.meta.imageHash ?? "")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .font(.caption)
    }
  }
}
