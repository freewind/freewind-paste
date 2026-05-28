import Foundation
import Observation

@MainActor
@Observable
final class ClipStore {
  var items: [ClipItem]

  init(items: [ClipItem] = []) {
    self.items = items
  }

  func item(for id: String) -> ClipItem? {
    items.first { $0.id == id }
  }

  func setItems(_ newItems: [ClipItem]) {
    items = newItems
  }

  func insertOrPromote(_ incoming: ClipItem) {
    var next = items
    if let index = next.firstIndex(where: { $0.dedupeKey() == incoming.dedupeKey() }) {
      let old = next.remove(at: index)
      var merged = incoming
      merged.trashedAt = nil
      merged.favorite = old.favorite
      merged.label = old.label.isEmpty ? incoming.label : old.label
      next.insert(merged, at: 0)
    } else {
      next.insert(incoming, at: 0)
    }
    items = next
  }

  func moveItems(
    within sectionIDs: [String],
    from offsets: IndexSet,
    to destination: Int
  ) {
    let sectionItems = sectionIDs.compactMap { id in
      items.first(where: { $0.id == id })
    }
    let movingIDs = offsets.map { sectionItems[$0].id }
    let remainingVisible = sectionItems.enumerated()
      .filter { !offsets.contains($0.offset) }
      .map(\.element.id)
    let clamped = min(destination, remainingVisible.count)
    let newVisibleOrder = Array(remainingVisible[..<clamped]) + movingIDs + Array(remainingVisible[clamped...])
    reorderItems(within: sectionIDs, newVisibleOrder: newVisibleOrder)
  }

  func moveItemBlock(
    within sectionIDs: [String],
    itemIDs: [String],
    by offset: Int
  ) -> Bool {
    guard offset == -1 || offset == 1 else {
      return false
    }

    let movingSet = Set(itemIDs)
    let movingIDs = sectionIDs.filter { movingSet.contains($0) }
    guard
      !movingIDs.isEmpty,
      let firstID = movingIDs.first,
      let lastID = movingIDs.last,
      let firstIndex = sectionIDs.firstIndex(of: firstID),
      let lastIndex = sectionIDs.firstIndex(of: lastID)
    else {
      return false
    }

    let remainingIDs = sectionIDs.filter { !movingSet.contains($0) }
    let insertIndex: Int
    let targetNeighborID: String

    if offset < 0 {
      guard firstIndex > 0 else {
        return false
      }
      targetNeighborID = sectionIDs[firstIndex - 1]
      insertIndex = remainingIDs.firstIndex(of: targetNeighborID) ?? 0
    } else {
      guard lastIndex < sectionIDs.count - 1 else {
        return false
      }
      targetNeighborID = sectionIDs[lastIndex + 1]
      insertIndex = (remainingIDs.firstIndex(of: targetNeighborID) ?? (remainingIDs.count - 1)) + 1
    }

    let newVisibleOrder = Array(remainingIDs[..<insertIndex]) + movingIDs + Array(remainingIDs[insertIndex...])
    reorderItems(within: sectionIDs, newVisibleOrder: newVisibleOrder)
    mergeMovedItemsIntoNeighborGroup(itemIDs: movingIDs, neighborID: targetNeighborID)
    return true
  }

  func reverseItems(_ ids: [String]) {
    guard ids.count > 1 else {
      return
    }

    let reversed = Array(ids.reversed())
    var mutable = items
    let positions = ids.compactMap { id in mutable.firstIndex(where: { $0.id == id }) }
    guard positions.count == ids.count else {
      return
    }

    for (index, position) in positions.enumerated() {
      let replacementID = reversed[index]
      if let replacement = items.first(where: { $0.id == replacementID }) {
        mutable[position] = replacement
      }
    }

    items = mutable
  }

  func toggleFavorite(for id: String) {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      return
    }
    items[index].favorite.toggle()
    items[index].updatedAt = .now
  }

  func setFavorite(_ ids: Set<String>, favorite: Bool) {
    guard !ids.isEmpty else {
      return
    }
    let now = Date.now
    for index in items.indices where ids.contains(items[index].id) {
      items[index].favorite = favorite
      items[index].updatedAt = now
    }
  }

  func updateLabel(for id: String, label: String) {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      return
    }
    items[index].label = label
    items[index].updatedAt = .now
  }

  func updateText(for id: String, text: String, languageGuess: String?) {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      return
    }
    items[index].content.text = text
    items[index].meta.textPreview = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\n", with: " ")
      .prefix(120)
      .description
    items[index].meta.languageGuess = languageGuess
    items[index].updatedAt = .now
  }

  func restore(_ ids: Set<String>) -> [String] {
    guard !ids.isEmpty else {
      return []
    }

    let now = Date.now
    var restoredIDs: [String] = []
    var restored: [ClipItem] = []

    items.removeAll { item in
      guard ids.contains(item.id) else {
        return false
      }
      var next = item
      next.trashedAt = nil
      next.updatedAt = now
      restoredIDs.append(next.id)
      restored.append(next)
      return true
    }

    items.insert(contentsOf: restored, at: 0)
    return restoredIDs
  }

  func pruneStaleNonFavorites(olderThan days: Int = 7, now: Date = .now) -> Bool {
    let cutoff = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
    let oldCount = items.count
    items.removeAll { item in
      guard !item.favorite else {
        return false
      }
      if let trashedAt = item.trashedAt {
        return trashedAt < cutoff
      }
      return item.createdAt < cutoff
    }
    return items.count != oldCount
  }

  func clearAll() {
    items.removeAll()
  }

  func delete(_ ids: Set<String>, permanently: Bool) {
    guard !ids.isEmpty else {
      return
    }

    if permanently {
      items.removeAll { ids.contains($0.id) }
      return
    }

    let now = Date.now
    for index in items.indices where ids.contains(items[index].id) {
      items[index].trashedAt = now
    }
  }

  private func reorderItems(within sectionIDs: [String], newVisibleOrder: [String]) {
    let visibleIDSet = Set(sectionIDs)
    let anchored = items.filter { !visibleIDSet.contains($0.id) }
    let reordered = newVisibleOrder.compactMap { id in
      items.first(where: { $0.id == id })
    }

    var result: [ClipItem] = []
    var reorderedIndex = 0
    var anchoredIndex = 0

    for item in items {
      if visibleIDSet.contains(item.id) {
        result.append(reordered[reorderedIndex])
        reorderedIndex += 1
      } else {
        result.append(anchored[anchoredIndex])
        anchoredIndex += 1
      }
    }

    items = result
  }

  private func mergeMovedItemsIntoNeighborGroup(itemIDs: [String], neighborID: String) {
    guard let neighbor = item(for: neighborID) else {
      return
    }

    let targetDate = neighbor.groupingDate
    let targetGroup = DateGroup.title(for: targetDate)
    let movingSet = Set(itemIDs)
    var next = items
    var changed = false

    for index in next.indices where movingSet.contains(next[index].id) {
      guard DateGroup.title(for: next[index].groupingDate) != targetGroup else {
        continue
      }

      if next[index].isTrashed {
        next[index].trashedAt = targetDate
      } else {
        next[index].updatedAt = targetDate
      }
      changed = true
    }

    if changed {
      items = next
    }
  }
}
