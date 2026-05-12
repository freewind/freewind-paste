import Combine
import AppKit
import Foundation

@MainActor
final class ClipStore: ObservableObject {
  enum VisibleCheckedState {
    case none
    case partial
    case all

    var iconName: String {
      switch self {
      case .none:
        return "square"
      case .partial:
        return "minus.square.fill"
      case .all:
        return "checkmark.square.fill"
      }
    }
  }

  @Published var items: [ClipItem]
  @Published var selectedIDs: Set<String>
  @Published var checkedIDs: Set<String>
  @Published var focusedID: String?
  @Published var currentTab: MainTab
  @Published var searchQuery: String
  @Published var kindFilter: ClipKindFilter
  @Published var previewLocked: Bool
  var selectionAnchorID: String?

  init(
    items: [ClipItem] = [],
    selectedIDs: Set<String> = [],
    checkedIDs: Set<String> = [],
    focusedID: String? = nil,
    currentTab: MainTab = .history,
    searchQuery: String = "",
    kindFilter: ClipKindFilter = .all,
    previewLocked: Bool = false
  ) {
    self.items = items
    self.selectedIDs = selectedIDs
    self.checkedIDs = checkedIDs
    self.focusedID = focusedID
    self.currentTab = currentTab
    self.searchQuery = searchQuery
    self.kindFilter = kindFilter
    self.previewLocked = previewLocked
    selectionAnchorID = focusedID ?? selectedIDs.first
  }

  var visibleItems: [ClipItem] {
    items
      .filter { item in
        switch currentTab {
        case .history:
          return !item.isTrashed
        case .favorites:
          return !item.isTrashed && item.favorite
        case .trash:
          return item.isTrashed
        }
      }
      .filter { item in
        switch kindFilter {
        case .all:
          return true
        case .text:
          return item.kind == .text
        case .image:
          return item.kind == .image
        case .file:
          return item.kind == .file
        }
      }
      .filter { SearchService.matches(item: $0, query: searchQuery) }
  }

  var groupedVisibleItems: [GroupedItems] {
    let groups = Dictionary(grouping: visibleItems) { item in
      DateGroup.title(for: item.groupingDate)
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
    if let focusedID, let item = visibleItems.first(where: { $0.id == focusedID }) {
      return item
    }
    return selectedItems.first ?? visibleItems.first
  }

  var selectedItems: [ClipItem] {
    visibleItems.filter { selectedIDs.contains($0.id) }
  }

  var checkedVisibleItems: [ClipItem] {
    visibleItems.filter { checkedIDs.contains($0.id) }
  }

  var checkedVisibleCount: Int {
    checkedVisibleItems.count
  }

  var allVisibleChecked: Bool {
    !visibleItems.isEmpty && checkedVisibleCount == visibleItems.count
  }

  var visibleCheckedState: VisibleCheckedState {
    if checkedVisibleCount == 0 {
      return .none
    }
    if allVisibleChecked {
      return .all
    }
    return .partial
  }

  func setItems(_ newItems: [ClipItem]) {
    items = newItems
    normalizeSelection()
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
    selectedIDs = [incoming.id]
    focusedID = incoming.id
    selectionAnchorID = incoming.id
  }

  func normalizeSelection() {
    let visibleIDs = Set(visibleItems.map(\.id))
    let allIDs = Set(items.map(\.id))

    selectedIDs = selectedIDs.intersection(visibleIDs)
    checkedIDs = checkedIDs.intersection(allIDs)

    if let focusedID, !visibleIDs.contains(focusedID) {
      self.focusedID = nil
    }

    if focusedID == nil {
      focusedID = selectedItems.first?.id ?? visibleItems.first?.id
    }

    if selectionAnchorID == nil || !visibleIDs.contains(selectionAnchorID ?? "") {
      selectionAnchorID = focusedID
    }
  }

  func select(_ ids: Set<String>) {
    selectedIDs = ids
    if let id = visibleItems.first(where: { ids.contains($0.id) })?.id {
      focusedID = id
      selectionAnchorID = id
    }
  }

  func focus(_ id: String?) {
    focusedID = id
    if let id {
      selectionAnchorID = id
    }
  }

  func selectFirstVisible() {
    guard let first = visibleItems.first else {
      selectedIDs.removeAll()
      focusedID = nil
      return
    }
    selectedIDs = [first.id]
    focusedID = first.id
    selectionAnchorID = first.id
  }

  func moveFocus(by offset: Int) {
    guard !visibleItems.isEmpty else {
      selectedIDs.removeAll()
      focusedID = nil
      return
    }

    let orderedIDs = visibleItems.map(\.id)
    let currentID = focusedID ?? orderedIDs.first
    let currentIndex = currentID.flatMap { orderedIDs.firstIndex(of: $0) } ?? 0
    let nextIndex = min(max(currentIndex + offset, 0), orderedIDs.count - 1)
    let nextID = orderedIDs[nextIndex]
    selectedIDs = [nextID]
    focusedID = nextID
    selectionAnchorID = nextID
  }

  func handleClick(
    on id: String,
    orderedIDs: [String],
    modifiers: NSEvent.ModifierFlags
  ) {
    if modifiers.contains(.shift) {
      let anchor = selectionAnchorID ?? focusedID ?? id
      guard
        let start = orderedIDs.firstIndex(of: anchor),
        let end = orderedIDs.firstIndex(of: id)
      else {
        selectedIDs = [id]
        focusedID = id
        selectionAnchorID = id
        return
      }
      let range = start <= end ? start...end : end...start
      selectedIDs = Set(orderedIDs[range])
      focusedID = id
      return
    }

    if modifiers.contains(.command) {
      if selectedIDs.contains(id) {
        selectedIDs.remove(id)
      } else {
        selectedIDs.insert(id)
      }
      focusedID = id
      selectionAnchorID = id
      return
    }

    selectedIDs = [id]
    focusedID = id
    selectionAnchorID = id
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
    normalizeSelection()
  }

  func toggleChecked(_ id: String) {
    if checkedIDs.contains(id) {
      checkedIDs.remove(id)
    } else {
      checkedIDs.insert(id)
    }
  }

  func setVisibleChecked(_ checked: Bool) {
    let ids = Set(visibleItems.map(\.id))
    if checked {
      checkedIDs.formUnion(ids)
    } else {
      checkedIDs.subtract(ids)
    }
  }

  func clearCheckedVisible() {
    checkedIDs.subtract(visibleItems.map(\.id))
  }

  func deleteCheckedVisible() {
    let ids = Set(checkedVisibleItems.map(\.id))
    guard !ids.isEmpty else {
      return
    }
    delete(ids, permanently: currentTab == .trash)
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
    normalizeSelection()
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
    delete(selectedIDs, permanently: currentTab == .trash)
  }

  func delete(_ id: String) {
    delete([id], permanently: currentTab == .trash)
  }

  func restoreSelected() {
    restore(selectedIDs)
  }

  func restore(_ id: String) {
    restore([id])
  }

  func restore(_ ids: Set<String>) {
    guard !ids.isEmpty else {
      return
    }

    let now = Date.now
    var restored: [ClipItem] = []

    items.removeAll { item in
      guard ids.contains(item.id) else {
        return false
      }
      var next = item
      next.trashedAt = nil
      next.updatedAt = now
      restored.append(next)
      return true
    }

    items.insert(contentsOf: restored, at: 0)
    selectedIDs = Set(restored.map(\.id))
    focusedID = restored.first?.id
    selectionAnchorID = focusedID
    normalizeSelection()
  }

  func pruneExpiredTrash(olderThan days: Int = 7, now: Date = .now) -> Bool {
    let cutoff = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
    let oldCount = items.count
    items.removeAll { item in
      guard let trashedAt = item.trashedAt else {
        return false
      }
      return trashedAt < cutoff
    }
    if items.count != oldCount {
      normalizeSelection()
      return true
    }
    return false
  }

  func clearAll() {
    items.removeAll()
    selectedIDs.removeAll()
    checkedIDs.removeAll()
    focusedID = nil
  }

  func delete(_ ids: Set<String>, permanently: Bool) {
    guard !ids.isEmpty else {
      return
    }
    if permanently {
      hardDelete(ids)
    } else {
      moveToTrash(ids)
    }
  }

  private func moveToTrash(_ ids: Set<String>) {
    let now = Date.now
    var trashed: [ClipItem] = []

    items.removeAll { item in
      guard ids.contains(item.id) else {
        return false
      }
      var next = item
      next.trashedAt = now
      next.updatedAt = now
      trashed.append(next)
      return true
    }

    items.insert(contentsOf: trashed, at: 0)
    checkedIDs.subtract(ids)
    selectedIDs.subtract(ids)
    focusedID = visibleItems.first?.id
    selectionAnchorID = focusedID
    normalizeSelection()
  }

  private func hardDelete(_ ids: Set<String>) {
    items.removeAll { ids.contains($0.id) }
    checkedIDs.subtract(ids)
    selectedIDs.subtract(ids)
    if let focusedID, ids.contains(focusedID) {
      self.focusedID = nil
    }
    selectionAnchorID = focusedID
    normalizeSelection()
  }
}
