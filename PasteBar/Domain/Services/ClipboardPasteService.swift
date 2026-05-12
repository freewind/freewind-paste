import AppKit
import Foundation

@MainActor
struct ClipboardPasteService {
  let trigger: AccessibilityPasteTrigger

  func paste(items: [ClipItem], mode: PasteMode, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) {
    guard !items.isEmpty else {
      return
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    switch mode {
    case .normalEnter:
      writeNormal(items: items, to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    case .nativeShiftEnter:
      writeNative(items: items, to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
      trigger.triggerPaste()
    }
  }

  private func writeNormal(items: [ClipItem], to pasteboard: NSPasteboard, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) {
    if items.count == 1, let first = items.first {
      switch first.kind {
      case .text:
        pasteboard.setString(first.content.text ?? "", forType: .string)
      case .image:
        writeNative(items: [first], to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
      case .file:
        let text = (first.content.filePaths ?? []).joined(separator: "\n")
        pasteboard.setString(text, forType: .string)
      }
      return
    }

    if items.allSatisfy({ $0.kind != .image }) {
      let text = items.compactMap { item -> String? in
        switch item.kind {
        case .text:
          return item.content.text
        case .file:
          return (item.content.filePaths ?? []).joined(separator: "\n")
        case .image:
          return nil
        }
      }
      .joined(separator: "\n")
      pasteboard.setString(text, forType: .string)
      return
    }

    let objects = items.flatMap { item in
      normalObjects(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }
    pasteboard.writeObjects(objects)
  }

  private func writeNative(items: [ClipItem], to pasteboard: NSPasteboard, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) {
    let objects = items.flatMap { item in
      nativeObjects(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }
    pasteboard.writeObjects(objects)
  }

  private func normalObjects(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> [NSPasteboardWriting] {
    switch item.kind {
    case .text:
      return [item.content.text as NSString?].compactMap { $0 }
    case .image:
      return [loadImage(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)].compactMap { $0 }
    case .file:
      let text = (item.content.filePaths ?? []).joined(separator: "\n")
      return [text as NSString]
    }
  }

  private func nativeObjects(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> [NSPasteboardWriting] {
    switch item.kind {
    case .text:
      return [item.content.text as NSString?].compactMap { $0 }
    case .image:
      return [loadImage(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)].compactMap { $0 }
    case .file:
      return (item.content.filePaths ?? [])
        .map { URL(fileURLWithPath: $0) as NSURL }
    }
  }

  private func loadImage(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> NSImage? {
    guard let path = item.content.imageAssetPath else {
      return nil
    }
    return ImageAssetStore(assetsDirectoryURL: AppPaths.assetsDirectoryURL)
      .load(relativePath: path, mode: imageOutputMode, maxDimension: imageMaxDimension)
  }
}
