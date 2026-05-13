import AppKit
import Foundation

enum MainTab: String, CaseIterable {
  case history
  case favorites
  case trash
}

enum ClipKindFilter: String, CaseIterable {
  case all
  case text
  case image
  case file

  var title: String {
    switch self {
    case .all:
      return ""
    case .text:
      return "Text"
    case .image:
      return "Image"
    case .file:
      return "File"
    }
  }
}

enum PasteMode {
  case normalEnter
  case nativeShiftEnter
}

enum ImageOutputMode: String, CaseIterable {
  case original
  case lowResolution

  var title: String {
    switch self {
    case .original:
      return "Original"
    case .lowResolution:
      return "Low"
    }
  }
}

@MainActor
final class ClipViewState: ObservableObject {
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

  let store: ClipStore

  @Published var selectedIDs: Set<String>
  @Published var checkedIDs: Set<String>
  @Published var focusedID: String?
  @Published var currentTab: MainTab
  @Published var searchQuery: String
  @Published var kindFilter: ClipKindFilter
  @Published private(set) var pageMoveRequestID: Int
  var selectionAnchorID: String?
  private var pendingPageMoveDirection: Int

  init(
    store: ClipStore,
    selectedIDs: Set<String> = [],
    checkedIDs: Set<String> = [],
    focusedID: String? = nil,
    currentTab: MainTab = .history,
    searchQuery: String = "",
    kindFilter: ClipKindFilter = .all,
    pageMoveRequestID: Int = 0
  ) {
    self.store = store
    self.selectedIDs = selectedIDs
    self.checkedIDs = checkedIDs
    self.focusedID = focusedID
    self.currentTab = currentTab
    self.searchQuery = searchQuery
    self.kindFilter = kindFilter
    self.pageMoveRequestID = pageMoveRequestID
    pendingPageMoveDirection = 0
    selectionAnchorID = focusedID ?? selectedIDs.first
  }

  var visibleItems: [ClipItem] {
    store.items
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

  func normalizeSelection() {
    let visibleIDs = Set(visibleItems.map(\.id))
    let allIDs = Set(store.items.map(\.id))

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

  func moveFocusExtendingSelection(by offset: Int) {
    let orderedIDs = visibleItems.map(\.id)
    guard !orderedIDs.isEmpty else {
      selectedIDs.removeAll()
      focusedID = nil
      return
    }

    let anchorID = selectionAnchorID ?? focusedID ?? orderedIDs.first
    guard let anchorID, let anchorIndex = orderedIDs.firstIndex(of: anchorID) else {
      moveFocus(by: offset)
      return
    }

    let currentIndex = orderedIDs.firstIndex(of: focusedID ?? anchorID) ?? anchorIndex
    let nextIndex = min(max(currentIndex + offset, 0), orderedIDs.count - 1)
    let range = anchorIndex <= nextIndex ? anchorIndex...nextIndex : nextIndex...anchorIndex
    selectedIDs = Set(orderedIDs[range])
    focusedID = orderedIDs[nextIndex]
    selectionAnchorID = anchorID
  }

  func moveFocusToScopeBoundary(isStart: Bool) {
    let scopeItems: [ClipItem]
    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      scopeItems = groupedVisibleItems.first(where: { $0.title == "Today" })?.items ?? []
    } else {
      scopeItems = visibleItems
    }

    guard let targetID = (isStart ? scopeItems.first : scopeItems.last)?.id else {
      return
    }

    selectedIDs = [targetID]
    focusedID = targetID
    selectionAnchorID = targetID
  }

  func requestPageMove(by direction: Int) {
    guard direction != 0 else {
      return
    }
    pendingPageMoveDirection = direction
    pageMoveRequestID += 1
  }

  func consumePendingPageMoveDirection() -> Int {
    let direction = pendingPageMoveDirection
    pendingPageMoveDirection = 0
    return direction
  }

  func collapseSelectionToAnchor() -> Bool {
    guard selectedIDs.count > 1 else {
      return false
    }

    let orderedIDs = visibleItems.map(\.id)
    let targetID = selectionAnchorID.flatMap { selectedIDs.contains($0) ? $0 : nil }
      ?? orderedIDs.first(where: { selectedIDs.contains($0) })

    guard let targetID else {
      return false
    }

    selectedIDs = [targetID]
    focusedID = targetID
    selectionAnchorID = targetID
    return true
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
      let previousAnchorID = selectionAnchorID.flatMap { orderedIDs.contains($0) ? $0 : nil }
        ?? orderedIDs.first(where: { selectedIDs.contains($0) })
        ?? id

      if selectedIDs.contains(id) {
        selectedIDs.remove(id)
      } else {
        selectedIDs.insert(id)
      }

      if selectedIDs.isEmpty {
        focusedID = nil
        selectionAnchorID = nil
        return
      }

      if selectedIDs.count == 1, let remainingID = selectedIDs.first {
        focusedID = remainingID
        selectionAnchorID = remainingID
        return
      }

      focusedID = id
      selectionAnchorID = selectedIDs.contains(previousAnchorID)
        ? previousAnchorID
        : orderedIDs.first(where: { selectedIDs.contains($0) })
      return
    }

    selectedIDs = [id]
    focusedID = id
    selectionAnchorID = id
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
}
