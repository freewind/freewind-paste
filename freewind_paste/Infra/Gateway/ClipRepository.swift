import Foundation

@MainActor
final class ClipRepository {
  let persistence: ClipPersistence
  let imageAssetStore: ImageAssetStore

  init(
    persistence: ClipPersistence,
    imageAssetStore: ImageAssetStore
  ) {
    self.persistence = persistence
    self.imageAssetStore = imageAssetStore
  }

  func loadItems() -> [ClipItem] {
    let loaded = persistence.loadItems()
    let sanitized = sanitizeLoadedItems(loaded)
    if sanitized != loaded {
      commitItems(sanitized)
    }
    return sanitized
  }

  func loadSettings() -> AppSettings {
    persistence.loadSettings()
  }

  func saveSettings(_ settings: AppSettings) {
    try? persistence.saveSettings(settings)
  }

  func commitItems(_ items: [ClipItem]) {
    try? persistence.saveItems(items)
    pruneAssets(for: items)
  }

  func clearAll() {
    persistence.resetAll()
  }

  private func pruneAssets(for items: [ClipItem]) {
    let keptImages = Set(
      items.compactMap { item in
        item.kind == .image ? item.content.imageAssetPath : nil
      }
    )
    imageAssetStore.prune(keeping: keptImages)
  }

  private func sanitizeLoadedItems(_ items: [ClipItem]) -> [ClipItem] {
    items.map { item in
      var next = item

      switch next.kind {
      case .text:
        let text = next.content.text ?? next.meta.textPreview ?? ""
        next.content.text = text
        if next.meta.textPreview?.isEmpty ?? true {
          next.meta.textPreview = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(120)
            .description
        }
      case .image:
        break
      case .file:
        let paths = next.content.filePaths ?? []
        if next.meta.fileCount == nil {
          next.meta.fileCount = paths.count
        }
        if next.meta.fileName == nil {
          next.meta.fileName = paths.first.map { URL(fileURLWithPath: $0).lastPathComponent }
        }
      }

      return next
    }
  }
}
