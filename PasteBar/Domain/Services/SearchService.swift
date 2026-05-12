import Foundation

enum SearchService {
  static func matches(item: ClipItem, query: String) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if needle.isEmpty {
      return true
    }

    let haystacks = [
      item.label,
      item.content.text ?? "",
      item.meta.textPreview ?? "",
      item.meta.fileName ?? "",
      (item.content.filePaths ?? []).joined(separator: "\n"),
    ]

    return haystacks.contains { $0.lowercased().contains(needle) }
  }
}
