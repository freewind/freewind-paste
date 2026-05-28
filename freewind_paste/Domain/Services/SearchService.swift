import Foundation

enum SearchService {
  static func normalizedNeedle(for query: String) -> String {
    query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  static func matchesPreview(item: ClipItem, query: String) -> Bool {
    matchesPreview(item: item, needle: normalizedNeedle(for: query))
  }

  static func matchesPreview(item: ClipItem, needle: String) -> Bool {
    if needle.isEmpty {
      return true
    }

    let haystacks = [
      item.label,
      item.meta.textPreview ?? "",
      item.meta.fileName ?? "",
    ]

    return haystacks.contains { $0.lowercased().contains(needle) }
  }

  static func expandedMatchIDs(
    in items: [ClipItem],
    needle: String,
    excluding ids: Set<String>
  ) -> Set<String> {
    guard !needle.isEmpty else {
      return []
    }

    return Set(
      items.lazy
        .filter { !ids.contains($0.id) }
        .filter { matchesExpandedContent(item: $0, needle: needle) }
        .map(\.id)
    )
  }

  private static func matchesExpandedContent(item: ClipItem, needle: String) -> Bool {
    let haystacks = [
      item.content.text ?? "",
      (item.content.filePaths ?? []).joined(separator: "\n"),
    ]

    return haystacks.contains { $0.lowercased().contains(needle) }
  }
}
