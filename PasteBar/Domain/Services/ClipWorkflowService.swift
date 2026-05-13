import AppKit
import Foundation

@MainActor
final class ClipWorkflowService {
  let store: ClipStore
  let uiState: ClipViewState
  let repository: ClipRepository
  let pasteService: ClipboardPasteService

  init(
    store: ClipStore,
    uiState: ClipViewState,
    repository: ClipRepository,
    pasteService: ClipboardPasteService
  ) {
    self.store = store
    self.uiState = uiState
    self.repository = repository
    self.pasteService = pasteService
  }

  func bootstrap() {
    uiState.normalizeSelection()
  }

  func labelValue(for id: String) -> String {
    store.item(for: id)?.label ?? ""
  }

  func capture(_ item: ClipItem, preserveCurrentSelection: Bool = false) {
    let selectedKeys = Set(uiState.selectedItems.map { $0.dedupeKey() })
    let focusedKey = uiState.focusedItem?.dedupeKey()
    let anchorKey = uiState.selectionAnchorID.flatMap { store.item(for: $0)?.dedupeKey() }

    store.insertOrPromote(item)

    guard preserveCurrentSelection else {
      uiState.select([item.id])
      commitItems()
      return
    }

    let visibleItems = uiState.visibleItems
    uiState.selectedIDs = Set(
      visibleItems
        .filter { selectedKeys.contains($0.dedupeKey()) }
        .map(\.id)
    )

    if let focusedKey {
      uiState.focusedID = visibleItems.first(where: { $0.dedupeKey() == focusedKey })?.id
    }

    if let anchorKey {
      uiState.selectionAnchorID = visibleItems.first(where: { $0.dedupeKey() == anchorKey })?.id
    }

    uiState.normalizeSelection()
    commitItems()
  }

  func pasteSelection(
    mode: PasteMode,
    imageOutputMode: ImageOutputMode,
    imageMaxDimension: Double,
    targetApplication: NSRunningApplication?
  ) -> String? {
    let items = uiState.selectedItems.isEmpty
      ? [uiState.focusedItem].compactMap { $0 }
      : uiState.selectedItems
    return paste(
      items: items,
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageMaxDimension,
      targetApplication: targetApplication
    )
  }

  func paste(
    ids: Set<String>,
    mode: PasteMode,
    imageOutputMode: ImageOutputMode,
    imageMaxDimension: Double,
    targetApplication: NSRunningApplication?
  ) -> String? {
    let items = uiState.visibleItems.filter { ids.contains($0.id) }
    return paste(
      items: items,
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageMaxDimension,
      targetApplication: targetApplication
    )
  }

  func updateText(for id: String, text: String, languageGuess: String?) {
    store.updateText(for: id, text: text, languageGuess: languageGuess)
    commitItems()
  }

  func updateLabel(for id: String, label: String) {
    store.updateLabel(for: id, label: label)
    commitItems()
  }

  func setFavorite(_ ids: Set<String>, favorite: Bool) {
    store.setFavorite(ids, favorite: favorite)
    commitItems()
  }

  func toggleFavorite(for id: String) {
    store.toggleFavorite(for: id)
    commitItems()
  }

  func moveItems(within sectionIDs: [String], from offsets: IndexSet, to destination: Int) {
    store.moveItems(within: sectionIDs, from: offsets, to: destination)
    uiState.normalizeSelection()
    commitItems()
  }

  func moveSelectionBlock(within sectionIDs: [String], itemIDs: [String], by offset: Int) -> Bool {
    guard store.moveItemBlock(within: sectionIDs, itemIDs: itemIDs, by: offset) else {
      return false
    }
    uiState.normalizeSelection()
    commitItems()
    return true
  }

  func reverseSelection() {
    store.reverseItems(uiState.selectedItems.map(\.id))
    uiState.normalizeSelection()
    commitItems()
  }

  func delete(_ ids: Set<String>, permanently: Bool) {
    let replacementID = replacementSelectionID(afterDeleting: ids)
    store.delete(ids, permanently: permanently)
    uiState.checkedIDs.subtract(ids)
    uiState.selectedIDs.subtract(ids)

    if let replacementID, uiState.visibleItems.contains(where: { $0.id == replacementID }) {
      uiState.select([replacementID])
    } else {
      uiState.normalizeSelection()
    }

    commitItems()
  }

  func restore(_ ids: Set<String>) {
    let restoredIDs = store.restore(ids)
    uiState.select(Set(restoredIDs))
    uiState.normalizeSelection()
    commitItems()
  }

  func clearAll() {
    store.clearAll()
    uiState.selectedIDs.removeAll()
    uiState.checkedIDs.removeAll()
    uiState.focusedID = nil
    repository.clearAll()
  }

  func copyLowResolutionImage(
    from item: ClipItem,
    imageMaxDimension: Double
  ) -> Bool {
    guard
      item.kind == .image,
      let path = item.content.imageAssetPath,
      let originalImage = repository.imageAssetStore.load(relativePath: path)
    else {
      return false
    }

    let transformed = repository.imageAssetStore.transformed(
      image: originalImage,
      mode: .lowResolution,
      maxDimension: imageMaxDimension
    )

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.writeObjects([transformed])
  }

  func pruneStaleItems() {
    if store.pruneStaleNonFavorites() {
      uiState.normalizeSelection()
      commitItems()
    }
  }

  private func paste(
    items: [ClipItem],
    mode: PasteMode,
    imageOutputMode: ImageOutputMode,
    imageMaxDimension: Double,
    targetApplication: NSRunningApplication?
  ) -> String? {
    let activeItems = items.filter { !$0.isTrashed }
    guard !activeItems.isEmpty else {
      return "Trash items can't paste"
    }

    pasteService.paste(
      items: activeItems,
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageMaxDimension,
      targetApplication: targetApplication
    )

    let usesLowResolution = imageOutputMode == .lowResolution && activeItems.contains { $0.kind == .image }
    switch (mode, usesLowResolution) {
    case (.normalEnter, true):
      return "Pasted low-res image"
    case (.nativeShiftEnter, true):
      return "Native pasted low-res image"
    case (.normalEnter, false):
      return "Pasted"
    case (.nativeShiftEnter, false):
      return "Native pasted"
    }
  }

  private func replacementSelectionID(afterDeleting ids: Set<String>) -> String? {
    let visibleIDs = uiState.visibleItemIDs
    guard
      let focusedID = uiState.focusedID,
      let focusedIndex = visibleIDs.firstIndex(of: focusedID)
    else {
      return visibleIDs.first { !ids.contains($0) }
    }

    let lowerBound = min(focusedIndex, visibleIDs.count - 1)
    if lowerBound >= 0 {
      for index in lowerBound..<visibleIDs.count where !ids.contains(visibleIDs[index]) {
        return visibleIDs[index]
      }
      if lowerBound > 0 {
        for index in stride(from: lowerBound - 1, through: 0, by: -1) where !ids.contains(visibleIDs[index]) {
          return visibleIDs[index]
        }
      }
    }

    return nil
  }

  private func commitItems() {
    repository.commitItems(store.items)
  }
}
