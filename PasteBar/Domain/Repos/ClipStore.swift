import Combine
import Foundation

@MainActor
final class ClipStore: ObservableObject {
  @Published var items: [ClipItem]
  @Published var selectedIDs: Set<String>
  @Published var focusedID: String?
  @Published var currentTab: MainTab
  @Published var searchQuery: String
  @Published var previewLocked: Bool

  init(
    items: [ClipItem] = [],
    selectedIDs: Set<String> = [],
    focusedID: String? = nil,
    currentTab: MainTab = .history,
    searchQuery: String = "",
    previewLocked: Bool = false
  ) {
    self.items = items
    self.selectedIDs = selectedIDs
    self.focusedID = focusedID
    self.currentTab = currentTab
    self.searchQuery = searchQuery
    self.previewLocked = previewLocked
  }

  var visibleItems: [ClipItem] {
    items
      .filter { currentTab == .history || $0.favorite }
      .filter { SearchService.matches(item: $0, query: searchQuery) }
  }

  var groupedVisibleItems: [GroupedItems] {
    let groups = Dictionary(grouping: visibleItems) { item in
      DateGroup.title(for: item.updatedAt)
    }

    return ["Today", "Yesterday", "Earlier"]
      .compactMap { title in
        guard let values = groups[title], !values.isEmpty else {
          return nil
        }
        return GroupedItems(id: title, title: title, items: values)
      }
  }

  var focusedItem: ClipItem? {
    if let focusedID, let item = items.first(where: { $0.id == focusedID }) {
      return item
    }
    if let firstSelected = visibleItems.first(where: { selectedIDs.contains($0.id) })?.id {
      return items.first(where: { $0.id == firstSelected })
    }
    return visibleItems.first
  }

  var selectedItems: [ClipItem] {
    items.filter { selectedIDs.contains($0.id) }
  }

  func setItems(_ newItems: [ClipItem]) {
    items = newItems
    if focusedID == nil {
      focusedID = visibleItems.first?.id
    }
  }

  func insertOrPromote(_ incoming: ClipItem) {
    var next = items
    if let index = next.firstIndex(where: { $0.dedupeKey() == incoming.dedupeKey() }) {
      let old = next.remove(at: index)
      var merged = incoming
      merged.favorite = old.favorite
      merged.label = old.label.isEmpty ? incoming.label : old.label
      next.insert(merged, at: 0)
    } else {
      next.insert(incoming, at: 0)
    }
    items = next
    selectedIDs = [incoming.id]
    focusedID = incoming.id
  }

  func select(_ ids: Set<String>) {
    selectedIDs = ids
    if let id = visibleItems.first(where: { ids.contains($0.id) })?.id {
      focusedID = id
    }
  }

  func focus(_ id: String?) {
    focusedID = id
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

    let visibleIDSet = Set(sectionIDs)
    let anchored = items.filter { !visibleIDSet.contains($0.id) }
    let reordered = newVisibleOrder.compactMap { id in items.first(where: { $0.id == id }) }

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

  func reverseSelection() {
    let ids = selectedItems.map(\.id)
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

  func deleteSelected() {
    items.removeAll { selectedIDs.contains($0.id) }
    selectedIDs.removeAll()
    focusedID = visibleItems.first?.id
  }

  func delete(_ id: String) {
    items.removeAll { $0.id == id }
    selectedIDs.remove(id)
    if focusedID == id {
      focusedID = visibleItems.first?.id
    }
  }

  func clearAll() {
    items.removeAll()
    selectedIDs.removeAll()
    focusedID = nil
  }
}
