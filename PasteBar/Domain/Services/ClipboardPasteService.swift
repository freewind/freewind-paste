import AppKit
import Foundation

@MainActor
struct ClipboardPasteService {
  let trigger: AccessibilityPasteTrigger

  func paste(
    items: [ClipItem],
    mode: PasteMode,
    imageOutputMode: ImageOutputMode,
    imageMaxDimension: Double,
    targetApplication: NSRunningApplication?
  ) {
    guard !items.isEmpty else {
      return
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    switch mode {
    case .normalEnter:
      writeNormal(items: items, to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    case .nativeShiftEnter:
      writeNative(items: items, to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
      targetApplication?.activate()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      trigger.triggerPaste()
    }
  }

  private func writeNormal(items: [ClipItem], to pasteboard: NSPasteboard, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) {
    if items.count == 1, let first = items.first {
      switch first.kind {
      case .text:
        pasteboard.setString(first.content.text ?? "", forType: .string)
      case .image:
        writeNative(items: [first], to: pasteboard, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
      case .file:
        let text = (first.content.filePaths ?? []).joined(separator: "\n")
        pasteboard.setString(text, forType: .string)
      }
      return
    }

    if items.allSatisfy({ $0.kind != .image }) {
      let text = items.compactMap { item -> String? in
        switch item.kind {
        case .text:
          return item.content.text
        case .file:
          return (item.content.filePaths ?? []).joined(separator: "\n")
        case .image:
          return nil
        }
      }
      .joined(separator: "\n")
      pasteboard.setString(text, forType: .string)
      return
    }

    let objects = items.flatMap { item in
      normalObjects(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }
    pasteboard.writeObjects(objects)
  }

  private func writeNative(items: [ClipItem], to pasteboard: NSPasteboard, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) {
    let objects = items.flatMap { item in
      nativeObjects(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)
    }
    pasteboard.writeObjects(objects)
  }

  private func normalObjects(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> [NSPasteboardWriting] {
    switch item.kind {
    case .text:
      return [item.content.text as NSString?].compactMap { $0 }
    case .image:
      return [loadImage(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)].compactMap { $0 }
    case .file:
      let text = (item.content.filePaths ?? []).joined(separator: "\n")
      return [text as NSString]
    }
  }

  private func nativeObjects(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> [NSPasteboardWriting] {
    switch item.kind {
    case .text:
      return [item.content.text as NSString?].compactMap { $0 }
    case .image:
      return [loadImage(for: item, imageOutputMode: imageOutputMode, imageMaxDimension: imageMaxDimension)].compactMap { $0 }
    case .file:
      return (item.content.filePaths ?? [])
        .map { URL(fileURLWithPath: $0) as NSURL }
    }
  }

  private func loadImage(for item: ClipItem, imageOutputMode: ImageOutputMode, imageMaxDimension: Double) -> NSImage? {
    guard let path = item.content.imageAssetPath else {
      return nil
    }
    return ImageAssetStore(assetsDirectoryURL: AppPaths.assetsDirectoryURL)
      .load(relativePath: path, mode: imageOutputMode, maxDimension: imageMaxDimension)
  }
}

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
    store.delete(ids, permanently: permanently)
    uiState.checkedIDs.subtract(ids)
    uiState.selectedIDs.subtract(ids)
    uiState.normalizeSelection()
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
      let image = repository.imageAssetStore.load(
        relativePath: path,
        mode: .lowResolution,
        maxDimension: imageMaxDimension
      ),
      let saved = try? repository.imageAssetStore.save(
        image,
        format: repository.imageAssetStore.preferredFormat(for: image, mode: .lowResolution)
      )
    else {
      return false
    }

    let trimmedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
    let newItem = ClipItem(
      kind: .image,
      favorite: item.favorite,
      label: trimmedLabel.isEmpty ? "" : "\(trimmedLabel) low",
      content: .image(assetPath: saved.relativePath),
      meta: ClipMeta(
        imageWidth: saved.width,
        imageHeight: saved.height,
        imageHash: saved.hash,
        imageByteSize: saved.byteSize
      )
    )
    store.insertOrPromote(newItem)
    uiState.select([newItem.id])
    commitItems()
    return true
  }

  func commitItems() {
    repository.commitItems(store.items)
  }
}
