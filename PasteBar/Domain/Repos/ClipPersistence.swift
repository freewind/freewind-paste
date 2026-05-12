import Foundation

final class ClipPersistence {
  let baseDirectoryURL: URL
  let itemsURL: URL
  let settingsURL: URL
  let assetsURL: URL

  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(appFolderName: String = "PasteBar") {
    let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    baseDirectoryURL = supportURL.appendingPathComponent(appFolderName, isDirectory: true)
    itemsURL = baseDirectoryURL.appendingPathComponent("items.jsonl")
    settingsURL = baseDirectoryURL.appendingPathComponent("settings.json")
    assetsURL = baseDirectoryURL.appendingPathComponent("assets", isDirectory: true)

    encoder = JSONEncoder()
    decoder = JSONDecoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    try? FileManager.default.createDirectory(
      at: assetsURL.appendingPathComponent("images", isDirectory: true),
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  func loadItems() -> [ClipItem] {
    guard let raw = try? String(contentsOf: itemsURL) else {
      return []
    }

    return raw
      .split(separator: "\n")
      .compactMap { line in
        try? decoder.decode(ClipItem.self, from: Data(line.utf8))
      }
  }

  func saveItems(_ items: [ClipItem]) throws {
    let lines = try items.map { item in
      let data = try encoder.encode(item)
      guard let line = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "PasteBar.ClipPersistence", code: 1)
      }
      return line
    }
    let payload = lines.joined(separator: "\n")
    try payload.write(to: itemsURL, atomically: true, encoding: .utf8)
  }

  func loadSettings() -> AppSettings {
    guard
      let data = try? Data(contentsOf: settingsURL),
      let value = try? decoder.decode(AppSettings.self, from: data)
    else {
      return .default
    }
    return value
  }

  func saveSettings(_ settings: AppSettings) throws {
    let data = try encoder.encode(settings)
    try data.write(to: settingsURL, options: .atomic)
  }

  func resetAll() {
    try? FileManager.default.removeItem(at: itemsURL)
    try? FileManager.default.removeItem(at: settingsURL)
    try? FileManager.default.removeItem(at: assetsURL)
    try? FileManager.default.createDirectory(
      at: assetsURL.appendingPathComponent("images", isDirectory: true),
      withIntermediateDirectories: true,
      attributes: nil
    )
  }
}

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
