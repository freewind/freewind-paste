import Foundation

struct ClipItem: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let kind: ClipKind
  var createdAt: Date
  var updatedAt: Date
  var trashedAt: Date?
  var favorite: Bool
  var label: String
  var content: ClipContent
  var meta: ClipMeta

  init(
    id: String = UUID().uuidString,
    kind: ClipKind,
    createdAt: Date = .now,
    updatedAt: Date = .now,
    trashedAt: Date? = nil,
    favorite: Bool = false,
    label: String = "",
    content: ClipContent,
    meta: ClipMeta
  ) {
    self.id = id
    self.kind = kind
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.trashedAt = trashedAt
    self.favorite = favorite
    self.label = label
    self.content = content
    self.meta = meta
  }

  var isTrashed: Bool {
    trashedAt != nil
  }

  var groupingDate: Date {
    trashedAt ?? updatedAt
  }

  var titleText: String {
    if !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return label
    }

    switch kind {
    case .text:
      return meta.textPreview ?? "Text"
    case .image:
      if let width = meta.imageWidth, let height = meta.imageHeight {
        return "Image \(width)x\(height)"
      }
      return "Image"
    case .file:
      if let count = meta.fileCount, count > 1 {
        return "\(meta.fileName ?? "Files") +\(count - 1)"
      }
      return meta.fileName ?? "File"
    }
  }

  var detailText: String {
    switch kind {
    case .text:
      return content.text ?? ""
    case .image:
      return meta.imageHash ?? ""
    case .file:
      return (content.filePaths ?? []).joined(separator: "\n")
    }
  }

  var normalizedTextPreview: String {
    if let text = meta.textPreview, !text.isEmpty {
      return text
    }
    if let text = content.text, !text.isEmpty {
      return String(text.prefix(120))
    }
    return ""
  }

  func dedupeKey() -> String {
    switch kind {
    case .text:
      return "text:\(content.text ?? "")"
    case .image:
      return "image:\(meta.imageHash ?? "")"
    case .file:
      let value = (content.filePaths ?? []).joined(separator: "\u{1F}")
      return "file:\(value)"
    }
  }
}
