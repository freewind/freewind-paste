import AppKit
import SwiftUI

struct HistoryListView: View {
  @Environment(AppState.self) private var appState
  @Environment(ClipViewState.self) private var uiState

  var body: some View {
    HistoryTableRepresentable(
      appState: appState,
      uiState: uiState,
      visibleItems: uiState.visibleItems,
      selectedIDs: uiState.selectedIDs,
      checkedIDs: uiState.checkedIDs,
      focusedID: uiState.focusedID,
      currentTab: uiState.currentTab,
      viewportMoveRequestID: uiState.viewportMoveRequestID
    )
    .onChange(of: uiState.selectedIDs) { _, newValue in
      guard !newValue.isEmpty else {
        return
      }

      if let focusedID = uiState.focusedID, newValue.contains(focusedID) {
        return
      }

      if let id = uiState.visibleItems.first(where: { newValue.contains($0.id) })?.id {
        uiState.focus(id)
      }
    }
  }
}

private struct HistoryTableRepresentable: NSViewRepresentable {
  let appState: AppState
  let uiState: ClipViewState
  let visibleItems: [ClipItem]
  let selectedIDs: Set<String>
  let checkedIDs: Set<String>
  let focusedID: String?
  let currentTab: MainTab
  let viewportMoveRequestID: Int

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSScrollView {
    context.coordinator.makeScrollView(parent: self)
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    context.coordinator.update(parent: self)
  }
}

private extension HistoryTableRepresentable {
  struct RenderState: Equatable {
    let visibleItems: [ClipItem]
    let selectedIDs: Set<String>
    let checkedIDs: Set<String>
    let focusedID: String?
    let currentTab: MainTab
    let viewportMoveRequestID: Int

    var visibleIDs: [String] {
      visibleItems.map(\.id)
    }

    func rowState(at index: Int) -> HistoryTableRowState {
      let item = visibleItems[index]
      return HistoryTableRowState(
        item: item,
        isSelected: selectedIDs.contains(item.id),
        isFocused: focusedID == item.id,
        isChecked: checkedIDs.contains(item.id),
        showsFavorite: currentTab != .trash
      )
    }
  }

  @MainActor
  final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    private enum Column: String, CaseIterable {
      case checked
      case favorite
      case content

      var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(rawValue)
      }
    }

    private weak var tableView: HistoryTableView?
    private weak var scrollView: NSScrollView?
    private var parent: HistoryTableRepresentable?
    private var renderState = RenderState(
      visibleItems: [],
      selectedIDs: [],
      checkedIDs: [],
      focusedID: nil,
      currentTab: .history,
      viewportMoveRequestID: 0
    )
    private let contextMenu = NSMenu()
    private var contextMenuItemID: String?

    func makeScrollView(parent: HistoryTableRepresentable) -> NSScrollView {
      self.parent = parent

      let scrollView = NSScrollView()
      scrollView.drawsBackground = false
      scrollView.borderType = .noBorder
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true

      let tableView = HistoryTableView()
      tableView.headerView = nil
      tableView.backgroundColor = .clear
      tableView.selectionHighlightStyle = .none
      tableView.allowsMultipleSelection = true
      tableView.allowsEmptySelection = true
      tableView.allowsColumnSelection = false
      tableView.allowsTypeSelect = false
      tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
      tableView.intercellSpacing = .zero
      tableView.rowHeight = 28
      tableView.focusRingType = .none
      tableView.gridStyleMask = []
      tableView.usesAlternatingRowBackgroundColors = false
      tableView.dataSource = self
      tableView.delegate = self
      tableView.menu = contextMenu
      tableView.registerForDraggedTypes([.string])
      tableView.setDraggingSourceOperationMask(.move, forLocal: true)
      contextMenu.delegate = self

      for column in Column.allCases {
        let tableColumn = NSTableColumn(identifier: column.identifier)
        tableColumn.resizingMask = column == .content ? .autoresizingMask : []
        switch column {
        case .checked, .favorite:
          tableColumn.width = 28
          tableColumn.minWidth = 28
          tableColumn.maxWidth = 28
        case .content:
          tableColumn.minWidth = 180
        }
        tableView.addTableColumn(tableColumn)
      }

      tableView.onRowClick = { [weak self] row, modifiers in
        self?.handleRowClick(row: row, modifiers: modifiers)
      }
      tableView.onRowDoubleClick = { [weak self] row in
        self?.handleRowDoubleClick(row: row)
      }
      tableView.onContextMenu = { [weak self] row in
        self?.prepareContextMenu(for: row)
      }
      tableView.dragItemProvider = { [weak self] row, event in
        self?.makeDragItem(for: row, event: event)
      }
      tableView.onSpaceKey = { [weak self] in
        self?.toggleFavoriteForFocusedItem()
      }

      scrollView.documentView = tableView
      self.tableView = tableView
      self.scrollView = scrollView

      update(parent: parent)
      return scrollView
    }

    func update(parent: HistoryTableRepresentable) {
      self.parent = parent

      guard let tableView else {
        return
      }

      let nextState = RenderState(
        visibleItems: parent.visibleItems,
        selectedIDs: parent.selectedIDs,
        checkedIDs: parent.checkedIDs,
        focusedID: parent.focusedID,
        currentTab: parent.currentTab,
        viewportMoveRequestID: parent.viewportMoveRequestID
      )

      let previousState = renderState
      let needsFullReload = previousState.visibleItems.map(\.id) != nextState.visibleItems.map(\.id)
        || previousState.currentTab != nextState.currentTab

      renderState = nextState

      if needsFullReload {
        tableView.reloadData()
      } else {
        reloadChangedRows(from: previousState, to: nextState)
      }

      syncSelection(in: tableView)
      updateVisibleRowViews(in: tableView)
      performViewportMoveIfNeeded(from: previousState, to: nextState, in: tableView)
      syncFocusedRowVisibility(from: previousState, to: nextState, in: tableView, force: needsFullReload)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
      renderState.visibleItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
      28
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
      let identifier = NSUserInterfaceItemIdentifier("HistoryTableRowView")
      let rowView = (tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryTableRowView)
        ?? HistoryTableRowView()
      rowView.identifier = identifier
      rowView.apply(renderState.rowState(at: row))
      return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
      guard
        let tableColumn,
        let column = Column(rawValue: tableColumn.identifier.rawValue)
      else {
        return nil
      }

      let rowState = renderState.rowState(at: row)
      switch column {
      case .checked:
        let cell = dequeueCheckCell(from: tableView)
        cell.configure(
          rowState: rowState,
          onToggle: { [weak self] in
            self?.toggleChecked(row: row)
          }
        )
        return cell
      case .favorite:
        let cell = dequeueFavoriteCell(from: tableView)
        cell.configure(
          rowState: rowState,
          onToggle: { [weak self] in
            self?.toggleFavorite(row: row)
          }
        )
        return cell
      case .content:
        let cell = dequeueContentCell(from: tableView)
        cell.configure(rowState: rowState)
        return cell
      }
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
      NSString(string: renderState.visibleItems[row].id)
    }

    func tableView(
      _ tableView: NSTableView,
      validateDrop info: NSDraggingInfo,
      proposedRow row: Int,
      proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
      guard
        let draggedItemID = draggingItemID(from: info),
        renderState.visibleIDs.contains(draggedItemID)
      else {
        return []
      }

      let destination = destinationRow(for: info, proposedRow: row, tableView: tableView)
      tableView.setDropRow(destination, dropOperation: .above)
      return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
      guard
        let parent,
        let draggedItemID = draggingItemID(from: info),
        let sourceIndex = renderState.visibleIDs.firstIndex(of: draggedItemID)
      else {
        return false
      }

      let destination = min(max(row, 0), renderState.visibleItems.count)
      if destination == sourceIndex || destination == sourceIndex + 1 {
        return false
      }

      parent.appState.moveItems(
        within: renderState.visibleIDs,
        from: IndexSet(integer: sourceIndex),
        to: destination
      )
      return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
      rebuildContextMenu(menu)
    }

    private func reloadChangedRows(from previousState: RenderState, to nextState: RenderState) {
      guard let tableView else {
        return
      }

      let changedIndexes = nextState.visibleItems.indices.filter { index in
        previousState.rowState(at: index) != nextState.rowState(at: index)
      }

      guard !changedIndexes.isEmpty else {
        return
      }

      tableView.reloadData(
        forRowIndexes: IndexSet(changedIndexes),
        columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
      )
    }

    private func syncSelection(in tableView: NSTableView) {
      let indexes = IndexSet(
        renderState.visibleItems.enumerated().compactMap { index, item in
          renderState.selectedIDs.contains(item.id) ? index : nil
        }
      )

      if tableView.selectedRowIndexes != indexes {
        tableView.selectRowIndexes(indexes, byExtendingSelection: false)
      }
    }

    private func updateVisibleRowViews(in tableView: NSTableView) {
      let visibleRows = tableView.rows(in: tableView.visibleRect)
      let startRow = max(visibleRows.location, 0)
      let endRow = min(visibleRows.location + visibleRows.length, renderState.visibleItems.count)
      guard startRow < endRow else {
        return
      }

      for row in startRow..<endRow {
        if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? HistoryTableRowView {
          rowView.apply(renderState.rowState(at: row))
        }
      }
    }

    private func performViewportMoveIfNeeded(from previousState: RenderState, to nextState: RenderState, in tableView: NSTableView) {
      guard
        previousState.viewportMoveRequestID != nextState.viewportMoveRequestID,
        let command = parent?.uiState.consumePendingViewportMoveCommand()
      else {
        return
      }

      tableView.layoutSubtreeIfNeeded()

      switch command {
      case let .page(direction):
        scrollPage(direction: direction, in: tableView)
      case let .boundary(isStart):
        scrollToBoundary(isStart: isStart, in: tableView)
      }
    }

    private func syncFocusedRowVisibility(from previousState: RenderState, to nextState: RenderState, in tableView: NSTableView, force: Bool) {
      guard force || previousState.focusedID != nextState.focusedID else {
        return
      }

      guard
        let focusedID = nextState.focusedID,
        let index = nextState.visibleIDs.firstIndex(of: focusedID)
      else {
        return
      }

      tableView.scrollRowToVisible(index)
    }

    private func scrollPage(direction: Int, in tableView: NSTableView) {
      guard direction != 0, let scrollView else {
        return
      }

      let visibleRect = scrollView.contentView.documentVisibleRect
      let maxY = max(tableView.bounds.height - visibleRect.height, 0)
      let nextY = visibleRect.origin.y + (CGFloat(direction) * visibleRect.height)
      scrollView.contentView.scroll(to: NSPoint(x: visibleRect.origin.x, y: min(max(nextY, 0), maxY)))
      scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func scrollToBoundary(isStart: Bool, in tableView: NSTableView) {
      guard let scrollView else {
        return
      }

      let visibleRect = scrollView.contentView.documentVisibleRect
      let maxY = max(tableView.bounds.height - visibleRect.height, 0)
      let targetY: CGFloat = isStart ? 0 : maxY
      scrollView.contentView.scroll(to: NSPoint(x: visibleRect.origin.x, y: targetY))
      scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func handleRowClick(row: Int, modifiers: NSEvent.ModifierFlags) {
      guard let parent else {
        return
      }

      let itemID = renderState.visibleItems[row].id
      parent.uiState.handleClick(
        on: itemID,
        orderedIDs: renderState.visibleIDs,
        modifiers: modifiers
      )
    }

    private func handleRowDoubleClick(row: Int) {
      guard let parent else {
        return
      }

      let itemID = renderState.visibleItems[row].id
      if !renderState.selectedIDs.contains(itemID) || renderState.selectedIDs.count <= 1 {
        parent.uiState.handleClick(
          on: itemID,
          orderedIDs: renderState.visibleIDs,
          modifiers: []
        )
      }
      parent.appState.pasteSelection(mode: .normalEnter)
    }

    private func toggleChecked(row: Int) {
      guard let parent else {
        return
      }

      parent.uiState.toggleChecked(renderState.visibleItems[row].id)
    }

    private func toggleFavorite(row: Int) {
      guard let parent else {
        return
      }

      parent.appState.toggleFavorite(for: renderState.visibleItems[row].id)
    }

    private func toggleFavoriteForFocusedItem() {
      guard
        let parent,
        renderState.currentTab != .trash,
        let itemID = renderState.focusedID ?? renderState.visibleItems.first(where: { renderState.selectedIDs.contains($0.id) })?.id
      else {
        return
      }

      parent.appState.toggleFavorite(for: itemID)
    }

    private func prepareContextMenu(for row: Int) {
      guard renderState.visibleItems.indices.contains(row) else {
        contextMenuItemID = nil
        return
      }

      contextMenuItemID = renderState.visibleItems[row].id
    }

    private func rebuildContextMenu(_ menu: NSMenu) {
      menu.removeAllItems()

      guard
        let parent,
        let item = contextMenuItem
      else {
        return
      }

      let targetIDs = contextTargetIDs(for: item)
      let isMultiTarget = targetIDs.count > 1

      if renderState.currentTab != .trash {
        menuItem("Paste", action: #selector(handleContextPaste), in: menu)

        menu.addItem(.separator())

        menuItem(
          parent.uiState.allFavorites(in: targetIDs) ? "Unfavorite" : "Favorite",
          action: #selector(handleContextFavorite),
          in: menu
        )

        let labelItem = menuItem(
          item.label.isEmpty ? "Add Label" : "Edit Label",
          action: #selector(handleContextLabel),
          in: menu
        )
        labelItem.isEnabled = !isMultiTarget

        menuItem("Move to Trash", action: #selector(handleContextTrash), in: menu)
      } else {
        menuItem("Restore", action: #selector(handleContextRestore), in: menu)
        menuItem("Delete Permanently", action: #selector(handleContextDeletePermanently), in: menu)
      }
    }

    @objc
    private func handleContextPaste() {
      guard let parent else {
        return
      }
      parent.appState.paste(contextTargetIDs(), mode: .normalEnter)
    }

    @objc
    private func handleContextFavorite() {
      guard let parent else {
        return
      }

      let targetIDs = contextTargetIDs()
      parent.appState.setFavorite(targetIDs, favorite: !parent.uiState.allFavorites(in: targetIDs))
    }

    @objc
    private func handleContextLabel() {
      guard let parent, let item = contextMenuItem else {
        return
      }
      parent.appState.promptForLabel(for: item.id)
    }

    @objc
    private func handleContextTrash() {
      guard let parent else {
        return
      }
      parent.appState.delete(contextTargetIDs(), permanently: false)
    }

    @objc
    private func handleContextRestore() {
      guard let parent else {
        return
      }
      parent.appState.restore(contextTargetIDs())
    }

    @objc
    private func handleContextDeletePermanently() {
      guard let parent else {
        return
      }
      parent.appState.delete(contextTargetIDs(), permanently: true)
    }

    private var contextMenuItem: ClipItem? {
      guard let contextMenuItemID else {
        return nil
      }
      return renderState.visibleItems.first(where: { $0.id == contextMenuItemID })
    }

    private func contextTargetIDs(for item: ClipItem) -> Set<String> {
      if renderState.selectedIDs.count > 1, renderState.selectedIDs.contains(item.id) {
        return renderState.selectedIDs
      }
      return [item.id]
    }

    private func contextTargetIDs() -> Set<String> {
      guard let item = contextMenuItem else {
        return []
      }
      return contextTargetIDs(for: item)
    }

    private func dequeueCheckCell(from tableView: NSTableView) -> HistoryCheckCellView {
      let identifier = NSUserInterfaceItemIdentifier("HistoryCheckCellView")
      let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryCheckCellView)
        ?? HistoryCheckCellView()
      cell.identifier = identifier
      return cell
    }

    private func dequeueFavoriteCell(from tableView: NSTableView) -> HistoryFavoriteCellView {
      let identifier = NSUserInterfaceItemIdentifier("HistoryFavoriteCellView")
      let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryFavoriteCellView)
        ?? HistoryFavoriteCellView()
      cell.identifier = identifier
      return cell
    }

    private func dequeueContentCell(from tableView: NSTableView) -> HistoryContentCellView {
      let identifier = NSUserInterfaceItemIdentifier("HistoryContentCellView")
      let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryContentCellView)
        ?? HistoryContentCellView()
      cell.identifier = identifier
      return cell
    }

    private func makeDragItem(for row: Int, event: NSEvent) -> NSDraggingItem? {
      guard let tableView, renderState.visibleItems.indices.contains(row) else {
        return nil
      }

      let itemID = renderState.visibleItems[row].id
      let pasteboardItem = NSPasteboardItem()
      pasteboardItem.setString(itemID, forType: .string)

      let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
      let rowRect = tableView.rect(ofRow: row)
      let image = rowDragImage(for: rowRect, in: tableView)
      draggingItem.setDraggingFrame(rowRect, contents: image)
      return draggingItem
    }

    @discardableResult
    private func menuItem(_ title: String, action: Selector, in menu: NSMenu) -> NSMenuItem {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
      item.target = self
      menu.addItem(item)
      return item
    }

    private func draggingItemID(from info: NSDraggingInfo) -> String? {
      info.draggingPasteboard.string(forType: .string)
    }

    private func destinationRow(for info: NSDraggingInfo, proposedRow _: Int, tableView: NSTableView) -> Int {
      let point = tableView.convert(info.draggingLocation, from: nil)
      let hoveredRow = tableView.row(at: point)
      guard hoveredRow >= 0 else {
        return renderState.visibleItems.count
      }

      let rowRect = tableView.rect(ofRow: hoveredRow)
      return point.y > rowRect.midY ? hoveredRow : hoveredRow + 1
    }

    private func rowDragImage(for rowRect: NSRect, in tableView: NSTableView) -> NSImage? {
      guard rowRect.width > 0, rowRect.height > 0 else {
        return nil
      }

      guard let rep = tableView.bitmapImageRepForCachingDisplay(in: rowRect) else {
        return nil
      }

      tableView.cacheDisplay(in: rowRect, to: rep)
      let image = NSImage(size: rowRect.size)
      image.addRepresentation(rep)
      return image
    }
  }
}
