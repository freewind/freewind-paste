import AppKit
import Foundation

struct ClipboardParseService {
  let imageAssetStore: ImageAssetStore

  func parse(pasteboard: NSPasteboard = .general) -> ClipItem? {
    if let fileItem = parseFiles(pasteboard: pasteboard) {
      return fileItem
    }
    if let imageItem = parseImage(pasteboard: pasteboard) {
      return imageItem
    }
    if let textItem = parseText(pasteboard: pasteboard) {
      return textItem
    }
    return nil
  }

  private func parseText(pasteboard: NSPasteboard) -> ClipItem? {
    guard let text = pasteboard.string(forType: .string) else {
      return nil
    }

    let trimmedPreview = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\n", with: " ")
    let preview = String(trimmedPreview.prefix(120))

    return ClipItem(
      kind: .text,
      content: .text(text),
      meta: ClipMeta(
        textPreview: preview.isEmpty ? "(empty)" : preview,
        languageGuess: LanguageGuessService.guess(for: text)
      )
    )
  }

  private func parseImage(pasteboard: NSPasteboard) -> ClipItem? {
    guard
      let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
      let image = images.first
    else {
      return nil
    }

    guard let saved = try? imageAssetStore.save(image) else {
      return nil
    }

    return ClipItem(
      kind: .image,
      content: .image(assetPath: saved.relativePath),
      meta: ClipMeta(
        imageWidth: saved.width,
        imageHeight: saved.height,
        imageHash: saved.hash,
        imageByteSize: saved.byteSize
      )
    )
  }

  private func parseFiles(pasteboard: NSPasteboard) -> ClipItem? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
    ]
    guard
      let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
      !urls.isEmpty
    else {
      return nil
    }

    let normalizedPaths = urls.map { PathNormalize.normalize($0.path) }
    let firstPath = normalizedPaths[0]
    let firstURL = URL(fileURLWithPath: firstPath)
    let resourceValues = normalizedPaths.map { path in
      try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    }
    let totalSize = resourceValues.reduce(into: Int64(0)) { partialResult, values in
      partialResult += Int64(values?.fileSize ?? 0)
    }
    let fileExists = normalizedPaths.allSatisfy {
      FileManager.default.fileExists(atPath: $0)
    }
    let latestModifiedAt = resourceValues
      .compactMap { $0?.contentModificationDate }
      .max()

    return ClipItem(
      kind: .file,
      content: .file(paths: normalizedPaths),
      meta: ClipMeta(
        fileName: firstURL.lastPathComponent,
        fileSize: totalSize,
        fileExists: fileExists,
        fileModifiedAt: latestModifiedAt,
        fileCount: normalizedPaths.count
      )
    )
  }
}
