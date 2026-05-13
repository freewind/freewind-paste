import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  @EnvironmentObject private var store: ClipStore
  @State private var draggedItemID: String?
  @State private var dropTarget: HistoryDropTarget?
  @State private var rowRegistry = HistoryRowRegistry()

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(uiState.visibleItems) { item in
          NativeClickableRow(
            itemID: item.id,
            registry: rowRegistry,
            content: AnyView(
              HistoryRowView(
                item: item,
                isDragActive: draggedItemID != nil,
                isDragged: draggedItemID == item.id,
                dropLine: dropLine(for: item.id)
              )
            ),
            onClick: { event in
              uiState.handleClick(
                on: item.id,
                orderedIDs: uiState.visibleItems.map(\.id),
                modifiers: event.modifierFlags
              )
            },
            onDoubleClick: {
              if uiState.selectedIDs.count <= 1 || !uiState.selectedIDs.contains(item.id) {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItems.map(\.id),
                  modifiers: []
                )
              }
              appState.pasteSelection(mode: .normalEnter)
            }
          )
            .id(item.id)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
              let targetIDs = contextTargetIDs(for: item)
              let isMultiTarget = targetIDs.count > 1

              if uiState.currentTab != .trash {
                Button("Paste") {
                  appState.paste(targetIDs, mode: .normalEnter)
                }

                Divider()

                Button(allFavorites(in: targetIDs) ? "Unfavorite" : "Favorite") {
                  appState.setFavorite(targetIDs, favorite: !allFavorites(in: targetIDs))
                }
                Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                  appState.promptForLabel(for: item.id)
                }
                .disabled(isMultiTarget)

                Button("Move to Trash") {
                  appState.workflowService.delete(targetIDs, permanently: false)
                }
              } else {
                Button("Restore") {
                  appState.workflowService.restore(targetIDs)
                }
                Button("Delete Permanently") {
                  appState.workflowService.delete(targetIDs, permanently: true)
                }
              }
            }
            .onDrag {
              if !uiState.selectedIDs.contains(item.id) {
                uiState.select([item.id])
              }
              draggedItemID = item.id
              dropTarget = nil
              return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(
              of: [UTType.text],
              delegate: HistoryRowDropDelegate(
                targetItemID: item.id,
                groupItemIDs: uiState.visibleItems.map(\.id),
                draggedItemID: $draggedItemID,
                dropTarget: $dropTarget,
                onMove: { offsets, destination in
                  appState.moveItems(within: uiState.visibleItems.map(\.id), from: offsets, to: destination)
                }
              )
            )
        }
      }
    }
    .background(
      DragEndMonitorView {
        guard draggedItemID != nil || dropTarget != nil else {
          return
        }
        draggedItemID = nil
        dropTarget = nil
      }
    )
    .onAppear {
      syncFocusedItemVisibility()
    }
    .onChange(of: uiState.selectedIDs) { _, newValue in
      guard draggedItemID == nil else {
        return
      }

      if let focusedID = uiState.focusedID, newValue.contains(focusedID) {
        return
      }

      if let id = uiState.visibleItems.first(where: { newValue.contains($0.id) })?.id {
        uiState.focus(id)
      }
    }
    .onChange(of: uiState.focusedID) { _, _ in
      guard draggedItemID == nil else {
        return
      }
      syncFocusedItemVisibility()
    }
    .onChange(of: uiState.pageMoveRequestID) { _, _ in
      guard draggedItemID == nil else {
        return
      }
      performPageMove()
    }
  }

  private func syncFocusedItemVisibility() {
    guard let focusedID = uiState.focusedID else {
      return
    }

    let orderedIDs = uiState.visibleItems.map(\.id)
    let reveal = uiState.consumePendingFocusedItemReveal()
    let anchor = unitPoint(for: reveal.anchor) ?? scrollAnchor(for: focusedID)
    DispatchQueue.main.async {
      rowRegistry.reveal(
        itemID: focusedID,
        orderedIDs: orderedIDs,
        anchor: anchor,
        force: reveal.force || anchor != nil
      )
    }
  }

  private func performPageMove() {
    let direction = uiState.consumePendingPageMoveDirection()
    guard direction != 0 else {
      return
    }

    let orderedIDs = uiState.visibleItems.map(\.id)
    guard !orderedIDs.isEmpty else {
      return
    }

    if rowRegistry.scrollPage(by: direction, orderedIDs: orderedIDs) {
      DispatchQueue.main.async {
        let nextID = rowRegistry.edgeVisibleItemID(
          orderedIDs: orderedIDs,
          direction: direction
        ) ?? fallbackPageTargetID(orderedIDs: orderedIDs, direction: direction)
        guard let nextID else {
          return
        }

        uiState.prepareFocusedItemReveal(anchor: direction < 0 ? .top : .bottom, force: true)
        uiState.select([nextID])
      }
      return
    }

    uiState.prepareFocusedItemReveal(anchor: direction < 0 ? .top : .bottom, force: true)
    if let nextID = fallbackPageTargetID(orderedIDs: orderedIDs, direction: direction) {
      uiState.select([nextID])
    }
  }

  private func unitPoint(for anchor: ClipViewState.FocusScrollAnchor?) -> UnitPoint? {
    switch anchor {
    case .top:
      return .top
    case .bottom:
      return .bottom
    case nil:
      return nil
    }
  }

  private func fallbackPageTargetID(orderedIDs: [String], direction: Int) -> String? {
    let currentID = uiState.focusedID ?? orderedIDs.first
    let currentIndex = currentID.flatMap { orderedIDs.firstIndex(of: $0) } ?? 0
    let pageStep = rowRegistry.pageStep(orderedIDs: orderedIDs)
    let nextIndex = min(max(currentIndex + (pageStep * direction), 0), orderedIDs.count - 1)
    return orderedIDs[nextIndex]
  }

  private func scrollAnchor(for itemID: String) -> UnitPoint? {
    if let firstID = uiState.visibleItems.first?.id, itemID == firstID {
      return .top
    }

    if let lastID = uiState.visibleItems.last?.id, itemID == lastID {
      return .bottom
    }

    for group in uiState.groupedVisibleItems {
      if let firstID = group.items.first?.id, itemID == firstID {
        return .top
      }
      if let lastID = group.items.last?.id, itemID == lastID {
        return .bottom
      }
    }

    return nil
  }

  private func dropLine(for itemID: String) -> HistoryRowView.DropLine {
    guard let dropTarget, dropTarget.itemID == itemID else {
      return .none
    }
    return dropTarget.isAfter ? .after : .before
  }

  private func contextTargetIDs(for item: ClipItem) -> Set<String> {
    if uiState.selectedIDs.count > 1, uiState.selectedIDs.contains(item.id) {
      return uiState.selectedIDs
    }
    return [item.id]
  }

  private func allFavorites(in ids: Set<String>) -> Bool {
    let targets = store.items.filter { ids.contains($0.id) }
    return !targets.isEmpty && targets.allSatisfy(\.favorite)
  }
}

@MainActor
private final class HistoryRowRegistry {
  private final class WeakRowView {
    weak var value: NativeClickableHostingView?

    init(_ value: NativeClickableHostingView) {
      self.value = value
    }
  }

  private var views: [String: WeakRowView] = [:]

  func register(_ view: NativeClickableHostingView, for itemID: String) {
    views[itemID] = WeakRowView(view)
    cleanup()
  }

  func unregister(itemID: String, view: NativeClickableHostingView) {
    guard let current = views[itemID]?.value, current === view else {
      return
    }
    views[itemID] = nil
  }

  func reveal(itemID: String, orderedIDs: [String], anchor: UnitPoint?, force: Bool) {
    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return
    }

    guard let rowView = views[itemID]?.value else {
      revealMissingRow(
        itemID: itemID,
        orderedIDs: orderedIDs,
        anchor: anchor,
        scrollView: scrollView,
        documentView: documentView
      )
      return
    }

    let rowFrame = rowView.convert(rowView.bounds, to: documentView)
    let visibleRect = scrollView.contentView.documentVisibleRect

    if !force, rowFrame.intersects(visibleRect) {
      return
    }

    var nextOrigin = visibleRect.origin
    if anchor == .top {
      nextOrigin.y = rowFrame.minY
    } else if anchor == .bottom {
      nextOrigin.y = rowFrame.maxY - visibleRect.height
    } else if rowFrame.minY < visibleRect.minY {
      nextOrigin.y = rowFrame.minY
    } else {
      nextOrigin.y = rowFrame.maxY - visibleRect.height
    }

    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    nextOrigin.y = min(max(nextOrigin.y, 0), maxY)
    scrollView.contentView.scroll(to: nextOrigin)
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }

  func pageStep(orderedIDs: [String]) -> Int {
    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return 10
    }

    let visibleRect = scrollView.contentView.documentVisibleRect
    let visibleCount = orderedIDs.reduce(into: 0) { count, itemID in
      guard let rowView = views[itemID]?.value else {
        return
      }
      let rowFrame = rowView.convert(rowView.bounds, to: documentView)
      if rowFrame.intersects(visibleRect) {
        count += 1
      }
    }

    return max(visibleCount - 1, 1)
  }

  func scrollPage(by direction: Int, orderedIDs: [String]) -> Bool {
    cleanup()

    guard
      direction != 0,
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return false
    }

    let visibleRect = scrollView.contentView.documentVisibleRect
    let overlap = min(max(visibleRect.height * 0.18, 36), visibleRect.height * 0.45)
    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    var nextOrigin = visibleRect.origin

    if direction < 0 {
      nextOrigin.y = max(visibleRect.minY - visibleRect.height + overlap, 0)
    } else {
      nextOrigin.y = min(visibleRect.minY + visibleRect.height - overlap, maxY)
    }

    guard abs(nextOrigin.y - visibleRect.origin.y) > 0.5 else {
      return false
    }

    scrollView.contentView.scroll(to: nextOrigin)
    scrollView.reflectScrolledClipView(scrollView.contentView)
    return true
  }

  func edgeVisibleItemID(orderedIDs: [String], direction: Int) -> String? {
    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return nil
    }

    let visibleRect = scrollView.contentView.documentVisibleRect
    let visibleIDs = orderedIDs.filter { itemID in
      guard let rowView = views[itemID]?.value else {
        return false
      }
      let rowFrame = rowView.convert(rowView.bounds, to: documentView)
      return rowFrame.intersects(visibleRect)
    }

    guard !visibleIDs.isEmpty else {
      return nil
    }

    return direction < 0 ? visibleIDs.first : visibleIDs.last
  }

  private func revealMissingRow(
    itemID: String,
    orderedIDs: [String],
    anchor: UnitPoint?,
    scrollView: NSScrollView,
    documentView: NSView
  ) {
    guard
      let targetIndex = orderedIDs.firstIndex(of: itemID),
      let visibleRange = visibleIndexRange(orderedIDs: orderedIDs, documentView: documentView, scrollView: scrollView)
    else {
      return
    }

    let referenceIndex: Int
    if anchor == .top {
      referenceIndex = visibleRange.lowerBound
    } else if anchor == .bottom {
      referenceIndex = visibleRange.upperBound
    } else if targetIndex < visibleRange.lowerBound {
      referenceIndex = visibleRange.lowerBound
    } else if targetIndex > visibleRange.upperBound {
      referenceIndex = visibleRange.upperBound
    } else {
      return
    }

    let rowHeight = averageVisibleRowHeight(
      orderedIDs: orderedIDs,
      documentView: documentView,
      scrollView: scrollView
    ) ?? 44
    let delta = CGFloat(targetIndex - referenceIndex) * rowHeight
    let visibleRect = scrollView.contentView.documentVisibleRect
    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    var nextOrigin = visibleRect.origin
    nextOrigin.y = min(max(visibleRect.origin.y + delta, 0), maxY)

    guard abs(nextOrigin.y - visibleRect.origin.y) > 0.5 else {
      return
    }

    scrollView.contentView.scroll(to: nextOrigin)
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }

  private func visibleIndexRange(
    orderedIDs: [String],
    documentView: NSView,
    scrollView: NSScrollView
  ) -> ClosedRange<Int>? {
    let visibleRect = scrollView.contentView.documentVisibleRect
    let visibleIndexes = orderedIDs.enumerated().compactMap { entry -> Int? in
      let (index, itemID) = entry
      guard let rowView = views[itemID]?.value else {
        return nil
      }
      let rowFrame = rowView.convert(rowView.bounds, to: documentView)
      return rowFrame.intersects(visibleRect) ? index : nil
    }

    guard let first = visibleIndexes.first, let last = visibleIndexes.last else {
      return nil
    }
    return first...last
  }

  private func averageVisibleRowHeight(
    orderedIDs: [String],
    documentView: NSView,
    scrollView: NSScrollView
  ) -> CGFloat? {
    let visibleRect = scrollView.contentView.documentVisibleRect
    let heights = orderedIDs.compactMap { itemID -> CGFloat? in
      guard let rowView = views[itemID]?.value else {
        return nil
      }
      let rowFrame = rowView.convert(rowView.bounds, to: documentView)
      return rowFrame.intersects(visibleRect) ? rowFrame.height : nil
    }

    guard !heights.isEmpty else {
      return nil
    }
    return heights.reduce(0, +) / CGFloat(heights.count)
  }

  private func cleanup() {
    views = views.filter { $0.value.value != nil }
  }
}

private struct NativeClickableRow: NSViewRepresentable {
  let itemID: String
  let registry: HistoryRowRegistry
  let content: AnyView
  let onClick: (NSEvent) -> Void
  let onDoubleClick: () -> Void

  func makeNSView(context: Context) -> NativeClickableHostingView {
    let view = NativeClickableHostingView(rootView: content)
    view.onClick = onClick
    view.onDoubleClick = onDoubleClick
    registry.register(view, for: itemID)
    return view
  }

  func updateNSView(_ nsView: NativeClickableHostingView, context: Context) {
    nsView.rootView = content
    nsView.onClick = onClick
    nsView.onDoubleClick = onDoubleClick
    registry.register(nsView, for: itemID)
  }

  static func dismantleNSView(_ nsView: NativeClickableHostingView, coordinator: ()) {
    // no-op; registry cleanup happens on next register/reveal pass
  }
}

private final class NativeClickableHostingView: NSHostingView<AnyView> {
  var onClick: ((NSEvent) -> Void)?
  var onDoubleClick: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    if shouldIgnoreRowClick(for: event) {
      super.mouseDown(with: event)
      return
    }

    onClick?(event)
    super.mouseDown(with: event)

    if event.clickCount == 2 {
      onDoubleClick?()
    }
  }

  private func shouldIgnoreRowClick(for event: NSEvent) -> Bool {
    let point = convert(event.locationInWindow, from: nil)
    guard let hitView = hitTest(point) else {
      return false
    }

    return hitView.hasAncestor(before: self) { view in
      view is NSButton || view is NSControl
    }
  }
}

private extension NSView {
  func hasAncestor(before ancestor: NSView, matching: (NSView) -> Bool) -> Bool {
    var current: NSView? = self
    while let view = current, view !== ancestor {
      if matching(view) {
        return true
      }
      current = view.superview
    }
    return false
  }
}

private struct DragEndMonitorView: NSViewRepresentable {
  let onMouseUp: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    context.coordinator.start(onMouseUp: onMouseUp)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.onMouseUp = onMouseUp
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stop()
  }

  final class Coordinator {
    var monitor: Any?
    var onMouseUp: (() -> Void)?

    func start(onMouseUp: @escaping () -> Void) {
      self.onMouseUp = onMouseUp
      stop()
      monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
        self?.onMouseUp?()
        return event
      }
    }

    func stop() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }
  }
}

private struct HistoryDropTarget: Equatable {
  let itemID: String
  let isAfter: Bool
}

private struct HistoryRowDropDelegate: DropDelegate {
  let targetItemID: String
  let groupItemIDs: [String]
  @Binding var draggedItemID: String?
  @Binding var dropTarget: HistoryDropTarget?
  let onMove: (IndexSet, Int) -> Void

  func dropEntered(info: DropInfo) {
    updateDropTarget(info: info)
  }

  func dropExited(info: DropInfo) {
    guard dropTarget?.itemID == targetItemID else {
      return
    }
    dropTarget = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    guard
      let draggedItemID,
      draggedItemID != targetItemID,
      let from = groupItemIDs.firstIndex(of: draggedItemID),
      let dropTarget,
      dropTarget.itemID == targetItemID,
      let to = groupItemIDs.firstIndex(of: targetItemID)
    else {
      self.draggedItemID = nil
      self.dropTarget = nil
      return false
    }

    if isNoopMove(from: from, to: to, isAfter: dropTarget.isAfter) {
      self.draggedItemID = nil
      self.dropTarget = nil
      return true
    }

    let destination = dropTarget.isAfter ? to + 1 : to
    onMove(IndexSet(integer: from), destination)
    self.draggedItemID = nil
    self.dropTarget = nil
    return true
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    updateDropTarget(info: info)
    return DropProposal(operation: .move)
  }

  func validateDrop(info: DropInfo) -> Bool {
    guard let draggedItemID else {
      return false
    }

    return draggedItemID != targetItemID
  }

  private func updateDropTarget(info: DropInfo) {
    guard
      let draggedItemID,
      draggedItemID != targetItemID
    else {
      return
    }

    let isAfter = info.location.y > 13
    dropTarget = HistoryDropTarget(itemID: targetItemID, isAfter: isAfter)
  }

  private func isNoopMove(from: Int, to: Int, isAfter: Bool) -> Bool {
    if from == to {
      return true
    }
    if isAfter, from == to + 1 {
      return true
    }
    if !isAfter, from + 1 == to {
      return true
    }
    return false
  }
}
