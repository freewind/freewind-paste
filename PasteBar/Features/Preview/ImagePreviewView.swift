import SwiftUI

struct ImagePreviewView: View {
  let item: ClipItem
  let imageAssetStore: ImageAssetStore
  let outputMode: ImageOutputMode

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if
        let path = item.content.imageAssetPath,
        let image = imageAssetStore.load(relativePath: path, mode: outputMode)
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
        Text("\(displaySize.width)x\(displaySize.height)")
        Spacer()
        if outputMode == .lowResolution {
          Text("Low-res paste")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text(item.meta.imageHash ?? "")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .font(.caption)
    }
  }

  private var displaySize: (width: Int, height: Int) {
    imageAssetStore.outputSize(
      for: item.meta.imageWidth ?? 0,
      height: item.meta.imageHeight ?? 0,
      mode: outputMode
    )
  }
}
