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
}
