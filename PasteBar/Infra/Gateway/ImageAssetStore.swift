import AppKit
import Foundation

final class ImageAssetStore {
  enum ImageFileFormat {
    case png
    case jpeg

    var fileExtension: String {
      switch self {
      case .png:
        return "png"
      case .jpeg:
        return "jpg"
      }
    }
  }

  let assetsDirectoryURL: URL

  init(assetsDirectoryURL: URL) {
    self.assetsDirectoryURL = assetsDirectoryURL
    try? FileManager.default.createDirectory(
      at: assetsDirectoryURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  func save(
    _ image: NSImage,
    id: String = UUID().uuidString,
    format: ImageFileFormat = .png,
    compressionFactor: CGFloat? = nil
  ) throws -> (relativePath: String, hash: String, width: Int, height: Int, byteSize: Int64) {
    guard
      let rep = bitmap(for: image),
      let data = encodedData(for: rep, format: format, compressionFactor: compressionFactor)
    else {
      throw NSError(domain: "PasteBar.ImageAssetStore", code: 1)
    }

    let hash = FileHash.sha256(data: data)
    let fileName = "\(id).\(format.fileExtension)"
    let fileURL = assetsDirectoryURL.appendingPathComponent(fileName)
    try data.write(to: fileURL, options: .atomic)
    return (
      relativePath: "images/\(fileName)",
      hash: hash,
      width: Int(rep.pixelsWide),
      height: Int(rep.pixelsHigh),
      byteSize: Int64(data.count)
    )
  }

  func load(relativePath: String) -> NSImage? {
    let fileURL = assetsDirectoryURL.deletingLastPathComponent().appendingPathComponent(relativePath)
    return NSImage(contentsOf: fileURL)
  }

  func load(relativePath: String, mode: ImageOutputMode, maxDimension: Double) -> NSImage? {
    guard let image = load(relativePath: relativePath) else {
      return nil
    }
    return transformed(image: image, mode: mode, maxDimension: maxDimension)
  }

  func transformed(image: NSImage, mode: ImageOutputMode, maxDimension: Double) -> NSImage {
    guard mode == .lowResolution else {
      return image
    }

    let resizedImage = resized(image: image, maxDimension: maxDimension) ?? image
    guard preferredFormat(for: resizedImage, mode: mode) == .jpeg else {
      return resizedImage
    }

    return recompressedJPEG(
      image: resizedImage,
      compressionFactor: compressionFactor(for: image, mode: mode, maxDimension: maxDimension)
    )
      ?? resizedImage
  }

  func outputSize(for width: Int, height: Int, mode: ImageOutputMode, maxDimension: Double) -> (width: Int, height: Int) {
    guard mode == .lowResolution else {
      return (width, height)
    }

    let longestSide = max(width, height)
    guard longestSide > 0, Double(longestSide) > maxDimension else {
      return (width, height)
    }

    let scale = maxDimension / Double(longestSide)
    let nextWidth = max(1, Int((Double(width) * scale).rounded()))
    let nextHeight = max(1, Int((Double(height) * scale).rounded()))
    return (nextWidth, nextHeight)
  }

  func byteSize(relativePath: String) -> Int64? {
    let fileURL = assetsDirectoryURL.deletingLastPathComponent().appendingPathComponent(relativePath)
    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
    return Int64(values?.fileSize ?? 0)
  }

  func estimatedByteSize(relativePath: String, mode: ImageOutputMode, maxDimension: Double) -> Int64? {
    guard let image = load(relativePath: relativePath) else {
      return nil
    }
    let rendered = transformed(image: image, mode: mode, maxDimension: maxDimension)
    guard let data = encodedData(
      for: rendered,
      format: preferredFormat(for: rendered, mode: mode),
      compressionFactor: compressionFactor(for: image, mode: mode, maxDimension: maxDimension)
    ) else {
      return nil
    }
    return Int64(data.count)
  }

  func compressionFactor(for image: NSImage, mode: ImageOutputMode, maxDimension: Double) -> CGFloat {
    guard mode == .lowResolution else {
      return 1
    }

    let longestSide = max(image.size.width, image.size.height)
    guard longestSide > 0 else {
      return 0.82
    }

    let clampedDimension = min(CGFloat(maxDimension), longestSide)
    let scale = max(min(clampedDimension / longestSide, 1), 0)
    return max(0.18, min(0.85, 0.18 + (0.67 * scale)))
  }

  func preferredFormat(for image: NSImage, mode: ImageOutputMode) -> ImageFileFormat {
    guard mode == .lowResolution else {
      return .png
    }

    guard let rep = bitmap(for: image), !rep.hasAlpha else {
      return .png
    }

    return .jpeg
  }

  func remove(relativePath: String) {
    let fileURL = assetsDirectoryURL.deletingLastPathComponent().appendingPathComponent(relativePath)
    try? FileManager.default.removeItem(at: fileURL)
  }

  func prune(keeping relativePaths: Set<String>) {
    let parentURL = assetsDirectoryURL.deletingLastPathComponent()
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: assetsDirectoryURL,
      includingPropertiesForKeys: nil
    ) else {
      return
    }

    for file in files {
      let relativePath = parentURL.relativePath.isEmpty
        ? file.lastPathComponent
        : "images/\(file.lastPathComponent)"
      if !relativePaths.contains(relativePath) {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }

  private func bitmap(for image: NSImage) -> NSBitmapImageRep? {
    guard let tiff = image.tiffRepresentation else {
      return nil
    }
    return NSBitmapImageRep(data: tiff)
  }

  private func encodedData(for image: NSImage, format: ImageFileFormat, compressionFactor: CGFloat? = nil) -> Data? {
    guard
      let rep = bitmap(for: image)
    else {
      return nil
    }
    return encodedData(for: rep, format: format, compressionFactor: compressionFactor)
  }

  private func encodedData(for rep: NSBitmapImageRep, format: ImageFileFormat, compressionFactor: CGFloat? = nil) -> Data? {
    switch format {
    case .png:
      return rep.representation(using: .png, properties: [:])
    case .jpeg:
      return rep.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionFactor ?? 0.82]
      )
    }
  }

  private func recompressedJPEG(image: NSImage, compressionFactor: CGFloat) -> NSImage? {
    guard
      let rep = bitmap(for: image),
      let data = rep.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionFactor]
      )
    else {
      return nil
    }

    return NSImage(data: data)
  }

  private func resized(image: NSImage, maxDimension: Double) -> NSImage? {
    guard image.size.width > 0, image.size.height > 0 else {
      return nil
    }

    let longestSide = max(image.size.width, image.size.height)
    guard longestSide > CGFloat(maxDimension) else {
      return image
    }

    let scale = CGFloat(maxDimension) / longestSide
    let size = NSSize(
      width: max(1, floor(image.size.width * scale)),
      height: max(1, floor(image.size.height * scale))
    )

    let result = NSImage(size: size)
    result.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
      in: NSRect(origin: .zero, size: size),
      from: NSRect(origin: .zero, size: image.size),
      operation: .copy,
      fraction: 1
    )
    result.unlockFocus()
    return result
  }
}
