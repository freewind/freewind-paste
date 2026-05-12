import AppKit
import Foundation

final class ImageAssetStore {
  let assetsDirectoryURL: URL

  init(assetsDirectoryURL: URL) {
    self.assetsDirectoryURL = assetsDirectoryURL
    try? FileManager.default.createDirectory(
      at: assetsDirectoryURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  func save(_ image: NSImage, id: String = UUID().uuidString) throws -> (relativePath: String, hash: String, width: Int, height: Int) {
    guard
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
    else {
      throw NSError(domain: "PasteBar.ImageAssetStore", code: 1)
    }

    let hash = FileHash.sha256(data: png)
    let fileName = "\(id).png"
    let fileURL = assetsDirectoryURL.appendingPathComponent(fileName)
    try png.write(to: fileURL, options: .atomic)
    return (
      relativePath: "images/\(fileName)",
      hash: hash,
      width: Int(rep.pixelsWide),
      height: Int(rep.pixelsHigh)
    )
  }

  func load(relativePath: String) -> NSImage? {
    let fileURL = assetsDirectoryURL.deletingLastPathComponent().appendingPathComponent(relativePath)
    return NSImage(contentsOf: fileURL)
  }

  func load(relativePath: String, mode: ImageOutputMode) -> NSImage? {
    guard let image = load(relativePath: relativePath) else {
      return nil
    }
    return transformed(image: image, mode: mode)
  }

  func transformed(image: NSImage, mode: ImageOutputMode) -> NSImage {
    guard
      mode == .lowResolution,
      let maxDimension = mode.maxDimension
    else {
      return image
    }
    return resized(image: image, maxDimension: maxDimension) ?? image
  }

  func outputSize(for width: Int, height: Int, mode: ImageOutputMode) -> (width: Int, height: Int) {
    guard
      mode == .lowResolution,
      let maxDimension = mode.maxDimension
    else {
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
