import SwiftUI

struct ImagePreviewView: View {
  @EnvironmentObject private var appState: AppState
  let item: ClipItem
  let imageAssetStore: ImageAssetStore
  let outputMode: ImageOutputMode
  var compact: Bool = false

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
        HStack(spacing: 10) {
          if outputMode == .lowResolution {
            Text("Long edge \(Int(appState.imageLowResMaxDimension))px · Quality \(Int(currentCompressionFactor * 100))%")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Menu {
            Button("Open") {
              appState.openItemResource(item)
            }
            Button("Reveal in Finder") {
              appState.revealItemResource(item)
            }
            Button("Save As") {
              appState.saveItemAs(item)
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .font(.system(size: 14))
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
        }

        if outputMode == .lowResolution {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
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

        GeometryReader { proxy in
          let fittedSize = fittedImageSize(for: image.size, in: proxy.size)
          let shouldShrink = fittedSize.width + 0.5 < image.size.width || fittedSize.height + 0.5 < image.size.height

          ZStack {
            Color.black.opacity(0.03)

            if shouldShrink {
              Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: fittedSize.width, height: fittedSize.height)
                .contentShape(Rectangle())
                .onTapGesture {
                  appState.previewImage(item)
                }
            } else {
              Image(nsImage: image)
                .frame(width: image.size.width, height: image.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                  appState.previewImage(item)
                }
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(
          maxWidth: .infinity,
          minHeight: compact ? nil : 140,
          maxHeight: compact ? 320 : .infinity
        )
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
    .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
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

  private var currentCompressionFactor: CGFloat {
    guard
      outputMode == .lowResolution,
      let path = item.content.imageAssetPath,
      let image = imageAssetStore.load(relativePath: path)
    else {
      return 1
    }
    return imageAssetStore.compressionFactor(
      for: image,
      mode: .lowResolution,
      maxDimension: appState.imageLowResMaxDimension
    )
  }

  private var sliderRange: ClosedRange<Double> {
    let maxSide = max(Double(item.meta.imageWidth ?? 0), Double(item.meta.imageHeight ?? 0))
    let upper = max(240, min(maxSide, 1600))
    return 240...upper
  }

  private func byteText(for bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }

  private func fittedImageSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
    guard
      imageSize.width > 0,
      imageSize.height > 0,
      containerSize.width > 0,
      containerSize.height > 0
    else {
      return imageSize
    }

    let widthScale = containerSize.width / imageSize.width
    let heightScale = containerSize.height / imageSize.height
    let scale = min(widthScale, heightScale, 1)

    return CGSize(
      width: imageSize.width * scale,
      height: imageSize.height * scale
    )
  }
}
