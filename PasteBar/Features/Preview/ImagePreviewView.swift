import SwiftUI

struct ImagePreviewView: View {
  @EnvironmentObject private var appState: AppState
  let item: ClipItem
  let imageAssetStore: ImageAssetStore
  let outputMode: ImageOutputMode

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if
        let path = item.content.imageAssetPath,
        let image = imageAssetStore.load(
          relativePath: path,
          mode: outputMode,
          maxDimension: appState.imageLowResMaxDimension
        )
      {
        if outputMode == .lowResolution {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
              Text("Long edge \(Int(appState.imageLowResMaxDimension))px")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Copy") {
                appState.copyLowResolutionImage(from: item)
              }
            }

            Slider(
              value: $appState.imageLowResMaxDimension,
              in: sliderRange,
              step: 16
            )
          }
        }

        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: 320)
          .background(Color.black.opacity(0.03))
          .clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        ContentUnavailableView("Image Missing", systemImage: "photo")
      }

      Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
        GridRow {
          Text("Original")
          Text("\(originalSize.width)x\(originalSize.height)")
          Text(byteText(for: originalBytes))
        }
        if outputMode == .lowResolution {
          GridRow {
            Text("Current")
            Text("\(currentSize.width)x\(currentSize.height)")
            Text(byteText(for: currentBytes))
          }
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var originalSize: (width: Int, height: Int) {
    (item.meta.imageWidth ?? 0, item.meta.imageHeight ?? 0)
  }

  private var currentSize: (width: Int, height: Int) {
    imageAssetStore.outputSize(
      for: item.meta.imageWidth ?? 0,
      height: item.meta.imageHeight ?? 0,
      mode: outputMode,
      maxDimension: appState.imageLowResMaxDimension
    )
  }

  private var originalBytes: Int64 {
    item.meta.imageByteSize
      ?? item.content.imageAssetPath.flatMap { imageAssetStore.byteSize(relativePath: $0) }
      ?? 0
  }

  private var currentBytes: Int64 {
    guard
      outputMode == .lowResolution,
      let path = item.content.imageAssetPath
    else {
      return originalBytes
    }
    return imageAssetStore.estimatedByteSize(
      relativePath: path,
      mode: .lowResolution,
      maxDimension: appState.imageLowResMaxDimension
    ) ?? originalBytes
  }

  private var sliderRange: ClosedRange<Double> {
    let maxSide = max(Double(item.meta.imageWidth ?? 0), Double(item.meta.imageHeight ?? 0))
    let upper = max(240, min(maxSide, 1600))
    return 240...upper
  }

  private func byteText(for bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}
